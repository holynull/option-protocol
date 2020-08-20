pragma solidity >=0.6.0;

import "./lib/CompoundOracleInterface.sol";
import "./lib/IWETH.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OptionsContract is Ownable, ERC20 {
    using SafeMath for uint256;

    struct Float {
        uint256 value;
        int32 exponent;
    }

    struct Vault {
        uint256 collateral; // 抵押币种的数量
        uint256 tokensIssued; // 发行的期权合约的数量
        uint256 underlying; // 获得的underlying的数量
        bool owned;
    }

    mapping(address => Vault) internal vaults;

    address payable[] internal vaultOwners;

    Float public minCollateralizationRatio = Float(1, 0);

    Float public strikePrice;

    //  1 token对underlying的比例
    uint8 public tokenExchangeRate = 1;

    uint256 internal windowSize;

    uint256 public expiry;

    int32 public collateralExp = -18;

    int32 public underlyingExp = -18;

    // 抵押币种
    IERC20 public collateral;

    // 标的币种
    IERC20 public underlying;

    // 计价币种
    IERC20 public strike;

    CompoundOracleInterface public COMPOUND_ORACLE;

    IWETH Weth;

    IUniswapV2Router02 public uniswapRouter02;

    constructor(
        string memory _name,
        string memory _symbol,
        IERC20 _collateral,
        int32 _collExp,
        IERC20 _underlying,
        int32 _underlyingExp,
        uint256 _strikePrice,
        int32 _strikeExp,
        IERC20 _strike,
        uint256 _expiry,
        address _oracleAddress,
        uint256 _windowSize,
        address _uniswapRouter2
    ) public ERC20(_name, _symbol) {
        require(block.timestamp < _expiry, "EXPIRED");
        require(_windowSize <= _expiry, "WINDOW_SIZE_BIGGER_THEN_EXPIRY");
        require(isWithinExponentRange(_collExp), "COLLEXP_WRONG");
        require(isWithinExponentRange(_underlyingExp), "UNDERLYINGEXP_WRONG");
        require(isWithinExponentRange(_strikeExp), "STRIKEEXP_WRONG");

        collateral = _collateral;
        collateralExp = _collExp;

        underlying = _underlying;
        underlyingExp = _underlyingExp;

        strikePrice = Float(_strikePrice, _strikeExp);
        strike = _strike;

        expiry = _expiry;
        COMPOUND_ORACLE = CompoundOracleInterface(_oracleAddress);
        windowSize = _windowSize;
        uniswapRouter02 = IUniswapV2Router02(_uniswapRouter2);
    }

    event VaultOpened(address payable vaultOwner);
    event ETHCollateralAdded(
        address payable vaultOwner,
        uint256 amount,
        address payer
    );
    
    event IssuedOTokens(
        address issuedTo,
        uint256 tokensIssued,
        address payable vaultOwner
    );
   
    event Exercise(
        uint256 amtUnderlyingToPay,
        uint256 amtCollateralToPay,
        address payable exerciser,
        address payable vaultExercisedFrom
    );
    event RedeemVaultBalance(
        uint256 amtCollateralRedeemed,
        uint256 amtUnderlyingRedeemed,
        address payable vaultOwner
    );
    event BurnOTokens(address payable vaultOwner, uint256 tokensBurned);
    event RemoveCollateral(uint256 amtRemoved, address payable vaultOwner);
    
    event RemoveUnderlying(
        uint256 amountUnderlying,
        address payable vaultOwner
    );

    /**
     * @dev Throws if called Options contract is expired.
     */
    modifier notExpired() {
        require(!hasExpired(), "Options contract expired");
        _;
    }

    function getVaultOwners() public view returns (address payable[] memory) {
        address payable[] memory owners;
        uint256 index = 0;
        for (uint256 i = 0; i < vaultOwners.length; i++) {
            if (hasVault(vaultOwners[i])) {
                owners[index] = vaultOwners[i];
                index++;
            }
        }

        return owners;
    }

    function hasVault(address payable owner) public view returns (bool) {
        return vaults[owner].owned;
    }

    function openVault() public notExpired returns (bool) {
        require(!hasVault(msg.sender), "Vault already created");

        vaults[msg.sender] = Vault(0, 0, 0, true);
        vaultOwners.push(msg.sender);

        emit VaultOpened(msg.sender);
        return true;
    }

    function isExerciseWindow() public view returns (bool) {
        return ((block.timestamp >= expiry.sub(windowSize)) &&
            (block.timestamp < expiry));
    }

    function hasExpired() public view returns (bool) {
        return (block.timestamp >= expiry);
    }

    function exercise(
        uint256 tokensToExercise,
        address payable[] memory vaultsToExerciseFrom
    ) public payable {
        Weth.deposit{value: msg.value}(); // 将eth换成weth，防止重入，行权两次
        for (uint256 i = 0; i < vaultsToExerciseFrom.length; i++) {
            address payable vaultOwner = vaultsToExerciseFrom[i];
            require(
                hasVault(vaultOwner),
                "CANNOT_EXERCISE_FROM_A_VAULT_THAT_DOESN'T_EXIST"
            );
            Vault storage vault = vaults[vaultOwner];
            if (tokensToExercise == 0) {
                return;
            } else if (vault.tokensIssued >= tokensToExercise) {
                _exercise(tokensToExercise, vaultOwner);
                return;
            } else {
                tokensToExercise = tokensToExercise.sub(vault.tokensIssued);
                _exercise(vault.tokensIssued, vaultOwner);
            }
        }
        require(
            tokensToExercise == 0,
            "SPECIFIED_VAULTS_HAVE_INSUFFICIENT_COLLATERAl"
        );
    }

    function removeUnderlying() public {
        require(hasVault(msg.sender), "VAULT_DOES_NOT_EXIST");
        Vault storage vault = vaults[msg.sender];

        require(vault.underlying > 0, "NO_UNDERLYING_BALANCE");

        uint256 underlyingToTransfer = vault.underlying;
        vault.underlying = 0;

        transferUnderlying(msg.sender, underlyingToTransfer);
        emit RemoveUnderlying(underlyingToTransfer, msg.sender);
    }

    /**
     * @notice Returns true if the given ERC20 is ETH.
     * @param _ierc20 the ERC20 asset.
     */
    function isETH(IERC20 _ierc20) public pure returns (bool) {
        return _ierc20 == IERC20(0);
    }

    function burnOTokens(uint256 amtToBurn) public notExpired {
        require(hasVault(msg.sender), "VAULT_DOES_NOT_EXIST");

        Vault storage vault = vaults[msg.sender];

        vault.tokensIssued = vault.tokensIssued.sub(amtToBurn);
        _burn(msg.sender, amtToBurn);

        emit BurnOTokens(msg.sender, amtToBurn);
    }

    function removeCollateral(uint256 amtToRemove) public notExpired {
        require(amtToRemove > 0, "CANNOT_REMOVE_0_COLLATERAL");
        require(hasVault(msg.sender), "VAULT_DOES_NOT_EXIST");

        Vault storage vault = vaults[msg.sender];
        require(
            amtToRemove <= getCollateral(msg.sender),
            "CAN'T_REMOVE_MORE_COLLATERAL_THAN_OWNED"
        );

        // check that vault will remain safe after removing collateral
        uint256 newCollateralBalance = vault.collateral.sub(amtToRemove);

        require(
            isSafe(newCollateralBalance, vault.tokensIssued),
            "VAULT_IS_UNSAFE"
        );

        // remove the collateral
        vault.collateral = newCollateralBalance;
        transferCollateral(msg.sender, amtToRemove);

        emit RemoveCollateral(amtToRemove, msg.sender);
    }

    function redeemVaultBalance() public {
        require(hasExpired(), "CAN'T_COLLECT_COLLATERAL_UNTIL_EXPIRY");
        require(hasVault(msg.sender), "VAULT_DOES_NOT_EXIST");

        // pay out owner their share
        Vault storage vault = vaults[msg.sender];

        // To deal with lower precision
        uint256 collateralToTransfer = vault.collateral;
        uint256 underlyingToTransfer = vault.underlying;

        vault.collateral = 0;
        vault.tokensIssued = 0;
        vault.underlying = 0;

        transferCollateral(msg.sender, collateralToTransfer);
        transferUnderlying(msg.sender, underlyingToTransfer);

        emit RedeemVaultBalance(
            collateralToTransfer,
            underlyingToTransfer,
            msg.sender
        );
    }

    function isUnsafe(address payable vaultOwner) public view returns (bool) {
        bool stillUnsafe = !isSafe(
            getCollateral(vaultOwner),
            getOTokensIssued(vaultOwner)
        );
        return stillUnsafe;
    }

    /**
     * @notice This function returns if an -30 <= exponent <= 30
     */
    function isWithinExponentRange(int32 val) internal pure returns (bool re) {
        re = ((val <= 30) && (val >= -30));
    }

    /**
     * @notice This function calculates and returns the amount of collateral in the vault
     */
    function getCollateral(address payable vaultOwner)
        internal
        view
        returns (uint256)
    {
        Vault storage vault = vaults[vaultOwner];
        return vault.collateral;
    }

    /**
     * @notice This function calculates and returns the amount of puts issued by the Vault
     */
    function getOTokensIssued(address payable vaultOwner)
        internal
        view
        returns (uint256)
    {
        Vault storage vault = vaults[vaultOwner];
        return vault.tokensIssued;
    }

    function _exercise(
        uint256 tokensToExercise,
        address payable vaultToExerciseFrom
    ) internal {
        // 1. before exercise window: revert
        require(
            isExerciseWindow(),
            "CAN'T_EXERCISE_OUTSIDE_OF_THE_EXERCISE_WINDOW"
        );

        require(hasVault(vaultToExerciseFrom), "VAULT_DOES_NOT_EXIST");

        Vault storage vault = vaults[vaultToExerciseFrom];
        require(tokensToExercise > 0, "CAN'T_EXERCISE_0_OTOKENS");
        // Check correct amount of oTokens passed in)
        require(
            tokensToExercise <= vault.tokensIssued,
            "CAN'T EXERCISE MORE OTOKENS THAN THE OWNER HAS"
        );
        // Ensure person calling has enough oTokens
        require(
            balanceOf(msg.sender) >= tokensToExercise,
            "NOT ENOUGH OTOKENS"
        );

        // 1. Check sufficient underlying
        // 1.1 update underlying balances
        uint256 amtUnderlyingToPay = tokensToExercise; // 默认1一个token对应一个underlying
        vault.underlying = vault.underlying.add(amtUnderlyingToPay);

        // 2. Calculate Collateral to pay
        // 2.1 Payout enough collateral to get (strikePrice * oTokens) amount of collateral
        // 实际付给buyer的抵押物数量，要根据当前collateral和strike的价格计算，然后给付。即有可能给付的数量多于（strike相对于collateral涨价了）或者少于（strike相对于collateral降价了）当初的抵押量；
        uint256 amtCollateralToPay = calculateCollateralToPay(
            tokensToExercise,
            Float(1, 0)
        );

        // 2.2 Take a small fee on every exercise
        // uint256 amtFee = calculateCollateralToPay(
        //     oTokensToExercise,
        //     transactionFee
        // );
        // totalFee = totalFee.add(amtFee);

        uint256 totalCollateralToPay = amtCollateralToPay; //.add(amtFee);
        require(
            totalCollateralToPay <= vault.collateral,
            "VAULT UNDERWATER, CAN'T EXERCISE"
        );

        // 3. Update collateral + oToken balances
        vault.collateral = vault.collateral.sub(totalCollateralToPay); // 扣除付出去的抵押物数量，多扣了amtCollateralToPay+amtFee；所以fee就留个oToken合约的所有者
        vault.tokensIssued = vault.tokensIssued.sub(tokensToExercise);

        // 4. Transfer in underlying, burn oTokens + pay out collateral
        // 4.1 Transfer in underlying
        if (isETH(underlying)) {
            require(msg.value == amtUnderlyingToPay, "INCORRECT MSG.VALUE");
        } else {
            require(
                underlying.transferFrom(
                    msg.sender,
                    address(this),
                    amtUnderlyingToPay
                ),
                "COULD NOT TRANSFER IN TOKENS"
            );
        }
        // 4.2 burn oTokens
        _burn(msg.sender, tokensToExercise);

        // 4.3 Pay out collateral
        transferCollateral(msg.sender, amtCollateralToPay);

        emit Exercise(
            amtUnderlyingToPay,
            amtCollateralToPay,
            msg.sender,
            vaultToExerciseFrom
        );
    }

    function _addCollateral(address payable vaultOwner, uint256 amt)
        internal
        notExpired
        returns (uint256)
    {
        Vault storage vault = vaults[vaultOwner];
        vault.collateral = vault.collateral.add(amt);

        return vault.collateral;
    }

    function isSafe(uint256 collateralAmt, uint256 tokensIssued)
        internal
        view
        returns (bool)
    {
        // get price from Oracle
        uint256 collateralToEthPrice = 1;
        uint256 strikeToEthPrice = 1;

        if (collateral != strike) {
            collateralToEthPrice = getPrice(address(collateral));
            strikeToEthPrice = getPrice(address(strike));
        }

        // check `oTokensIssued * minCollateralizationRatio * strikePrice <= collAmt * collateralToStrikePrice` 流通期权合约的相对抵押物的价值，不能小于vault中抵押物的 1/16
        uint256 leftSideVal = tokensIssued
            .mul(minCollateralizationRatio.value)
            .mul(strikePrice.value);
        int32 leftSideExp = minCollateralizationRatio.exponent +
            strikePrice.exponent;

        uint256 rightSideVal = (collateralAmt.mul(collateralToEthPrice)).div(
            strikeToEthPrice
        );
        int32 rightSideExp = collateralExp;

        uint256 exp = 0;
        bool stillSafe = false;
        // 避免浮点比较大小，用乘法避免用除法
        if (rightSideExp < leftSideExp) {
            exp = uint256(leftSideExp - rightSideExp);
            stillSafe = leftSideVal.mul(10**exp) <= rightSideVal;
        } else {
            exp = uint256(rightSideExp - leftSideExp);
            stillSafe = leftSideVal <= rightSideVal.mul(10**exp);
        }

        return stillSafe;
    }

    function maxOTokensIssuable(uint256 collateralAmt)
        public
        view
        returns (uint256)
    {
        return calculateOTokens(collateralAmt, minCollateralizationRatio);
    }

    function calculateOTokens(uint256 collateralAmt, Float memory proportion)
        internal
        view
        returns (uint256)
    {
        // get price from Oracle
        uint256 collateralToEthPrice = 1;
        uint256 strikeToEthPrice = 1;

        if (collateral != strike) {
            collateralToEthPrice = getPrice(address(collateral));
            strikeToEthPrice = getPrice(address(strike));
        }

        // oTokensIssued  <= collAmt * collateralToStrikePrice / (proportion * strikePrice)
        uint256 denomVal = proportion.value.mul(strikePrice.value);
        int32 denomExp = proportion.exponent + strikePrice.exponent;

        uint256 numeratorVal = (collateralAmt.mul(collateralToEthPrice)).div(
            strikeToEthPrice
        );
        int32 numeratorExp = collateralExp;

        uint256 exp = 0;
        uint256 numOptions = 0;

        if (numeratorExp < denomExp) {
            exp = uint256(denomExp - numeratorExp);
            numOptions = numeratorVal.div(denomVal.mul(10**exp));
        } else {
            exp = uint256(numeratorExp - denomExp);
            numOptions = numeratorVal.mul(10**exp).div(denomVal);
        }

        return numOptions;
    }

    function calculateCollateralToPay(uint256 _tokens, Float memory proportion)
        internal
        view
        returns (uint256)
    {
        // Get price from oracle
        uint256 collateralToEthPrice = 1;
        uint256 strikeToEthPrice = 1;

        // 据实际情况看来，当前所有的期权合约抵押collateral全部都是标的strike币，所以全部不满足这个条件
        if (collateral != strike) {
            // 抵押币非计价币时，需要取抵押币的对eth价格，和strike币对eth的价格；
            collateralToEthPrice = getPrice(address(collateral));
            strikeToEthPrice = getPrice(address(strike));
        }

        // calculate how much should be paid out
        // collateral的数量等于oToken的数量乘以strikePrice
        uint256 amtCollateralToPayInEthNum = _tokens
            .mul(strikePrice.value)
            .mul(proportion.value)
            .mul(strikeToEthPrice);
        int32 amtCollateralToPayExp = strikePrice.exponent +
            proportion.exponent -
            collateralExp;
        uint256 amtCollateralToPay = 0;
        if (amtCollateralToPayExp > 0) {
            uint32 exp = uint32(amtCollateralToPayExp);
            amtCollateralToPay = amtCollateralToPayInEthNum.mul(10**exp).div(
                collateralToEthPrice
            );
        } else {
            uint32 exp = uint32(-1 * amtCollateralToPayExp);
            amtCollateralToPay = (amtCollateralToPayInEthNum.div(10**exp)).div(
                collateralToEthPrice
            );
        }

        return amtCollateralToPay;
    }

    function transferCollateral(address payable _addr, uint256 _amt) internal {
        if (isETH(collateral)) {
            Weth.withdraw(_amt);
            _addr.transfer(_amt);
        } else {
            collateral.transfer(_addr, _amt);
        }
    }

    function transferUnderlying(address payable _addr, uint256 _amt) internal {
        if (isETH(underlying)) {
            Weth.withdraw(_amt);
            _addr.transfer(_amt);
        } else {
            underlying.transfer(_addr, _amt);
        }
    }

    function getPrice(address asset) internal view returns (uint256) {
        if (asset == address(0)) {
            return (10**18);
        } else {
            return COMPOUND_ORACLE.getPrice(asset);
        }
    }

    function createCollateralOption(uint256 amtToCreate, uint256 amtCollateral)
        external
        payable
    {
        openVault();
        require(hasVault(msg.sender), "VAULT DOES NOT EXIST");
        uint256 liquidityEth = 0;
        uint256 collateralEth = 0;
        if (isETH(collateral)) {
            liquidityEth = msg.value.sub(amtCollateral);
            collateralEth = amtCollateral;
        } else {
            liquidityEth = msg.value;
        }
        require(liquidityEth > 0, "NO SUFFICIENT ETH TO ADD LIQUIDITY");
        // 先转代币，免得付不起gas
        require(
            collateral.transferFrom(msg.sender, address(this), amtCollateral),
            "COULD NOT TRANSFER IN COLLATERAL TOKENS"
        );

        if (isETH(collateral)) {
            // 把抵押的eth存上，还有剩余的做流动性的eth
            Weth.deposit{value: collateralEth}();
        }

        Vault storage vault = vaults[msg.sender];
        vault.collateral = vault.collateral.add(amtCollateral);
        emit ETHCollateralAdded(msg.sender, msg.value, msg.sender);

        //check that we're properly collateralized to mint this number, then call _mint(address account, uint256 amount)
        require(hasVault(msg.sender), "VAULT_DOES_NOT_EXIST");

        // checks that the vault is sufficiently collateralized
        uint256 newTokensBalance = vault.tokensIssued.add(amtToCreate);
        require(isSafe(vault.collateral, newTokensBalance), "UNSAFE_TO_MINT");

        // issue the oTokens
        vault.tokensIssued = newTokensBalance;
        _mint(msg.sender, amtToCreate);

        emit IssuedOTokens(msg.sender, amtToCreate, msg.sender);
        
        // IERC20 oToken = IERC20(address(this));
        // todo: 这可能不对
        // require(
        //     oToken.approve(
        //         address(optionsExchange.uniswapRouter02),
        //         amtToCreate
        //     ),
        //     "APPROVE FAILED"
        // );
        (
            ,
            uint256 amountETH,
            uint256 liquidity
        ) = uniswapRouter02.addLiquidityETH{
            value: liquidityEth
        }(address(this), amtToCreate, 1, 1, msg.sender, block.timestamp);
        if (liquidity > amountETH)
            TransferHelper.safeTransferETH(msg.sender, liquidity - amountETH);
    }
}
