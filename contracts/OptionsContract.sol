pragma solidity 0.6.0;

import "./lib/CompoundOracleInterface.sol";
import "./lib/IWETH.sol";
import "./OptionsExchange.sol";
import "./OptionsUtils.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title Opyn's Options Contract
 * @author Opyn
 */
contract OptionsContract is Ownable, ERC20 {
    using SafeMath for uint256;

    struct Float {
        uint256 value;
        int32 exponent;
    }

    struct Vault {
        uint256 collateral; // 抵押币种的数量
        uint256 poTokensIssued; // 发行的期权合约的数量
        uint256 underlying; // 获得的underlying的数量
        bool owned;
    }

    OptionsExchange public optionsExchange;

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

    string public name;

    string public symbol;

    // 本合约数量的小数位数
    uint8 public decimals;

    IWETH Weth;

    /**
     * @param _collaterald
     * @param _collExp
     * @param _underlying
     * @param _underlyingExp
     * @param _oTokenExchangeExp
     * @param _strikePrice
     * @param _strikeExp
     * @param _strike
     * @param _expiry
     * @param _optionsExchange
     * @param _oracleAddress
     * @param _windowSize
     */
    constructor(
        IERC20 _collateral,
        int32 _collExp,
        IERC20 _underlying,
        int32 _underlyingExp,
        uint256 _strikePrice,
        int32 _strikeExp,
        IERC20 _strike,
        uint256 _expiry,
        OptionsExchange _optionsExchange,
        address _oracleAddress,
        uint256 _windowSize,
        uint8 _decimals,
        address _weth
    ) public {
        require(block.timestamp < _expiry, "EXPIRED");
        require(_windowSize <= _expiry, "WINDOW_SIZE_BIGGER_THEN_EXPIRY");
        require(isWithinExponentRange(_collExp), "COLLEXP_WRONG");
        require(isWithinExponentRange(_underlyingExp), "UNDERLYINGEXP_WRONG");
        require(isWithinExponentRange(_strikeExp), "STRIKEEXP_WRONG");

        collateral = _collateral;
        collateralExp = _collExp;

        underlying = _underlying;
        underlyingExp = _underlyingExp;
        // tokenExchangeRate = Float(1, _oTokenExchangeExp);

        strikePrice = Float(_strikePrice, _strikeExp);
        strike = _strike;

        expiry = _expiry;
        COMPOUND_ORACLE = CompoundOracleInterface(_oracleAddress);
        optionsExchange = _optionsExchange;
        windowSize = _windowSize;
        decimals = _decimals;
        Weth = IWETH(_weth);
    }

    event VaultOpened(address payable vaultOwner);
    event ETHCollateralAdded(
        address payable vaultOwner,
        uint256 amount,
        address payer
    );
    event ERC20CollateralAdded(
        address payable vaultOwner,
        uint256 amount,
        address payer
    );
    event IssuedOTokens(
        address issuedTo,
        uint256 oTokensIssued,
        address payable vaultOwner
    );
    event Liquidate(
        uint256 amtCollateralToPay,
        address payable vaultOwner,
        address payable liquidator
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
    event BurnOTokens(address payable vaultOwner, uint256 oTokensBurned);
    event RemoveCollateral(uint256 amtRemoved, address payable vaultOwner);
    event UpdateParameters(
        uint256 minCollateralizationRatioValue,
        int32 minCollateralizationRatioExp,
        address owner
    );
    event TransferFee(address payable to, uint256 fees);
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
        uint256 oTokensToExercise,
        address payable[] memory vaultsToExerciseFrom
    ) public payable {
        require(Weth.deposit{value: msg.value}(), "ETH_SWAP_WETH_FAILED"); // 将eth换成weth，防止重入，行权两次
        for (uint256 i = 0; i < vaultsToExerciseFrom.length; i++) {
            address payable vaultOwner = vaultsToExerciseFrom[i];
            require(
                hasVault(vaultOwner),
                "Cannot exercise from a vault that doesn't exist"
            );
            Vault storage vault = vaults[vaultOwner];
            if (oTokensToExercise == 0) {
                return;
            } else if (vault.oTokensIssued >= oTokensToExercise) {
                _exercise(oTokensToExercise, vaultOwner);
                return;
            } else {
                oTokensToExercise = oTokensToExercise.sub(vault.oTokensIssued);
                _exercise(vault.oTokensIssued, vaultOwner);
            }
        }
        require(
            oTokensToExercise == 0,
            "Specified vaults have insufficient collateral"
        );
    }

    function removeUnderlying() public {
        require(hasVault(msg.sender), "Vault does not exist");
        Vault storage vault = vaults[msg.sender];

        require(vault.underlying > 0, "No underlying balance");

        uint256 underlyingToTransfer = vault.underlying;
        vault.underlying = 0;

        transferUnderlying(msg.sender, underlyingToTransfer);
        emit RemoveUnderlying(underlyingToTransfer, msg.sender);
    }

    function issueOTokens(uint256 oTokensToIssue, address receiver)
        public
        notExpired
    {
        //check that we're properly collateralized to mint this number, then call _mint(address account, uint256 amount)
        require(hasVault(msg.sender), "Vault does not exist");

        Vault storage vault = vaults[msg.sender];

        // checks that the vault is sufficiently collateralized
        uint256 newOTokensBalance = vault.oTokensIssued.add(oTokensToIssue);
        require(isSafe(vault.collateral, newOTokensBalance), "unsafe to mint");

        // issue the oTokens
        vault.oTokensIssued = newOTokensBalance;
        _mint(receiver, oTokensToIssue);

        emit IssuedOTokens(receiver, oTokensToIssue, msg.sender);
        return;
    }

    function getVault(address payable vaultOwner)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            bool
        )
    {
        Vault storage vault = vaults[vaultOwner];
        return (
            vault.collateral,
            vault.oTokensIssued,
            vault.underlying,
            vault.owned
        );
    }

    /**
     * @notice Returns true if the given ERC20 is ETH.
     * @param _ierc20 the ERC20 asset.
     */
    function isETH(IERC20 _ierc20) public pure returns (bool) {
        return _ierc20 == IERC20(0);
    }

    function burnOTokens(uint256 amtToBurn) public notExpired {
        require(hasVault(msg.sender), "Vault does not exist");

        Vault storage vault = vaults[msg.sender];

        vault.oTokensIssued = vault.oTokensIssued.sub(amtToBurn);
        _burn(msg.sender, amtToBurn);

        emit BurnOTokens(msg.sender, amtToBurn);
    }

    function removeCollateral(uint256 amtToRemove) public notExpired {
        require(amtToRemove > 0, "Cannot remove 0 collateral");
        require(hasVault(msg.sender), "Vault does not exist");

        Vault storage vault = vaults[msg.sender];
        require(
            amtToRemove <= getCollateral(msg.sender),
            "Can't remove more collateral than owned"
        );

        // check that vault will remain safe after removing collateral
        uint256 newCollateralBalance = vault.collateral.sub(amtToRemove);

        require(
            isSafe(newCollateralBalance, vault.oTokensIssued),
            "Vault is unsafe"
        );

        // remove the collateral
        vault.collateral = newCollateralBalance;
        transferCollateral(msg.sender, amtToRemove);

        emit RemoveCollateral(amtToRemove, msg.sender);
    }

    function redeemVaultBalance() public {
        require(hasExpired(), "Can't collect collateral until expiry");
        require(hasVault(msg.sender), "Vault does not exist");

        // pay out owner their share
        Vault storage vault = vaults[msg.sender];

        // To deal with lower precision
        uint256 collateralToTransfer = vault.collateral;
        uint256 underlyingToTransfer = vault.underlying;

        vault.collateral = 0;
        vault.oTokensIssued = 0;
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
    function isWithinExponentRange(int32 val) internal pure returns (bool) {
        return ((val <= 30) && (val >= -30));
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
        return vault.oTokensIssued;
    }

    function _exercise(
        uint256 oTokensToExercise,
        address payable vaultToExerciseFrom
    ) internal {
        // 1. before exercise window: revert
        require(
            isExerciseWindow(),
            "Can't exercise outside of the exercise window"
        );

        require(hasVault(vaultToExerciseFrom), "Vault does not exist");

        Vault storage vault = vaults[vaultToExerciseFrom];
        require(oTokensToExercise > 0, "Can't exercise 0 oTokens");
        // Check correct amount of oTokens passed in)
        require(
            oTokensToExercise <= vault.oTokensIssued,
            "Can't exercise more oTokens than the owner has"
        );
        // Ensure person calling has enough oTokens
        require(
            balanceOf(msg.sender) >= oTokensToExercise,
            "Not enough oTokens"
        );

        // 1. Check sufficient underlying
        // 1.1 update underlying balances
        uint256 amtUnderlyingToPay = oTokensToExercise; // 默认1一个token对应一个underlying
        vault.underlying = vault.underlying.add(amtUnderlyingToPay);

        // 2. Calculate Collateral to pay
        // 2.1 Payout enough collateral to get (strikePrice * oTokens) amount of collateral
        // 实际付给buyer的抵押物数量，要根据当前collateral和strike的价格计算，然后给付。即有可能给付的数量多于（strike相对于collateral涨价了）或者少于（strike相对于collateral降价了）当初的抵押量；
        uint256 amtCollateralToPay = calculateCollateralToPay(
            oTokensToExercise,
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
            "Vault underwater, can't exercise"
        );

        // 3. Update collateral + oToken balances
        vault.collateral = vault.collateral.sub(totalCollateralToPay); // 扣除付出去的抵押物数量，多扣了amtCollateralToPay+amtFee；所以fee就留个oToken合约的所有者
        vault.oTokensIssued = vault.oTokensIssued.sub(oTokensToExercise);

        // 4. Transfer in underlying, burn oTokens + pay out collateral
        // 4.1 Transfer in underlying
        if (isETH(underlying)) {
            require(msg.value == amtUnderlyingToPay, "Incorrect msg.value");
        } else {
            require(
                underlying.transferFrom(
                    msg.sender,
                    address(this),
                    amtUnderlyingToPay
                ),
                "Could not transfer in tokens"
            );
        }
        // 4.2 burn oTokens
        _burn(msg.sender, oTokensToExercise);

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

    /**
     * This function returns the maximum amount of oTokens that can safely be issued against the specified amount of collateral.
     * @param collateralAmt The amount of collateral against which oTokens will be issued.
     */
    function maxOTokensIssuable(uint256 collateralAmt)
        public
        view
        returns (uint256)
    {
        return calculateOTokens(collateralAmt, minCollateralizationRatio);
    }

    /**
     * @notice This function is used to calculate the amount of tokens that can be issued.
     * @dev The amount of oTokens is determined by:
     * oTokensIssued  <= collateralAmt * collateralToStrikePrice / (proportion * strikePrice)
     * @param collateralAmt The amount of collateral
     * @param proportion The proportion of the collateral to pay out. If 100% of collateral
     * should be paid out, pass in Number(1, 0). The proportion might be less than 100% if
     * you are calculating fees.
     */
    function calculateOTokens(uint256 collateralAmt, Number memory proportion)
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

    /**
     * @notice This function calculates the amount of collateral to be paid out.
     * @dev The amount of collateral to paid out is determined by:
     * (proportion * strikePrice * strikeToCollateralPrice * oTokens) amount of collateral.
     * @param _oTokens The number of oTokens.
     * @param proportion The proportion of the collateral to pay out. If 100% of collateral
     * should be paid out, pass in Number(1, 0). The proportion might be less than 100% if
     * you are calculating fees.
     * 公式：oTokenNum.mul(strikePrice).mul(strikeToEthPrice).div(collateralToEthPrice)
     */
    function calculateCollateralToPay(
        uint256 _oTokens,
        Number memory proportion
    ) internal view returns (uint256) {
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
        uint256 amtCollateralToPayInEthNum = _oTokens
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

    /**
     * @notice This function transfers `amt` collateral to `_addr`
     * @param _addr The address to send the collateral to
     * @param _amt The amount of the collateral to pay out.
     */
    function transferCollateral(address payable _addr, uint256 _amt) internal {
        if (isETH(collateral)) {
            require(Weth.withdraw(_amt), "WETH_SWAP_ETH_FAILED");
            _addr.transfer(_amt);
        } else {
            collateral.transfer(_addr, _amt);
        }
    }

    /**
     * @notice This function transfers `amt` underlying to `_addr`
     * @param _addr The address to send the underlying to
     * @param _amt The amount of the underlying to pay out.
     */
    function transferUnderlying(address payable _addr, uint256 _amt) internal {
        if (isETH(underlying)) {
            require(Weth.withdraw(_amt), "WETH_SWAP_ETH_FAILED");
            _addr.transfer(_amt);
        } else {
            underlying.transfer(_addr, _amt);
        }
    }

    /**
     * @notice This function gets the price ETH (wei) to asset price.
     * @param asset The address of the asset to get the price of
     */
    function getPrice(address asset) internal view returns (uint256) {
        if (asset == address(0)) {
            return (10**18);
        } else {
            return COMPOUND_ORACLE.getPrice(asset);
        }
    }

    function createCollateralOption(uint256 amtToCreate, address receiver)
        external
        payable
    {
        openVault();
        addCollateralOption(amtToCreate, receiver);
    }

    function addCollateralOption(uint256 amtToCreate, address receiver)
        public
        payable
    {
        addCollateral(msg.sender);
        issueOTokens(amtToCreate, receiver);
    }

    function addCollateral(address payable vaultOwner)
        public
        payable
        notExpired
        returns (uint256)
    {
        require(hasVault(vaultOwner), "Vault does not exist");
        if (isETH(collateral)) {
            require(Weth.deposit{value: msg.value}(), "ETH_SWAP_WETH_FAILED");
        }
        emit ETHCollateralAdded(vaultOwner, msg.value, msg.sender);
        return _addCollateral(vaultOwner, msg.value);
    }
}
