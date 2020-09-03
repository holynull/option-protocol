pragma solidity >=0.6.0;

import "./lib/IWETH.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface CompoundOracleInterface {
    // returns asset:eth -- to get USDC:eth, have to do 10**24/result,

    /**
     * @notice retrieves price of an asset
     * @dev function to get price for an asset
     * @param asset Asset for which to get the price
     * @return uint mantissa of asset price (scaled by 1e18) or zero if unset or contract paused
     */
    function getPrice(address asset) external view returns (uint256);

    function getUnderlyingPrice(IERC20 cToken) external view returns (uint256);
    // function getPrice(address asset) public view returns (uint) {
    //     return 527557000000000;
    // }
}

interface IPloutozOptExchange {
    function Weth() external view returns (address addr);

    function sellOTokens(address oTokenAddress, uint256 oTokensToSell)
        external
        returns (uint256[] memory amounts);

    function buyOTokens(address oTokenAddress, uint256 oTokensToBuy)
        external
        payable
        returns (uint256[] memory amounts);

    function addLiquidityETH(uint256 amtToCreate, address optContractAddresss)
        external
        payable
        returns (uint256 amountETH, uint256 liquidity);

    function redeemLiquidity(
        address optContractAddress,
        address payable receiver,
        uint256 amt
    ) external returns (uint256 amountToken, uint256 amountETH);

    // 能卖多少eth
    function premiumReceived(address oTokenAddress, uint256 oTokensToSell)
        external
        view
        returns (uint256 amt);

    // 能买多少出来
    function premiumToPay(address oTokenAddress, uint256 oTokensToBuy)
        external
        view
        returns (uint256 amts);

    function getLiquidityBalance(address owner, address optContractAddress)
        external
        view
        returns (uint256 liquidity);
}

contract PloutozOptContract is Ownable, ERC20 {
    using SafeMath for uint256;

    struct Vault {
        uint256 collateral; // wei, 抵押币种的数量
        uint256 tokensIssued; // wei, 发行的期权合约的数量
        uint256 underlying; // wei, 获得的underlying的数量,
        uint256 liquidity; // wei
        bool owned;
    }

    mapping(address => Vault) internal vaults;

    address payable[] internal vaultOwners;

    uint256 public minCollateralizationRatio = uint256(10**18); // wei

    // call 情况下，实际是价格的倒数
    uint256 public strikePrice; // strikePirce.mul(10**(0-strikePriceDecimals))

    uint8 public strikePriceDecimals;

    //  1 token对underlying的比例
    uint8 public tokenExchangeRate = 1;

    uint256 public windowSize;

    uint256 public expiry;

    // 抵押币种
    ERC20 public collateral;

    // 标的币种
    ERC20 public underlying;

    // 计价币种
    ERC20 public strike;

    CompoundOracleInterface public COMPOUND_ORACLE;

    IWETH Weth;

    IPloutozOptExchange public exchange;

    address exchangeAddress;

    constructor(
        string memory _name,
        string memory _symbol,
        address _underlying,
        address _strike,
        address _collateral,
        uint256 _strikePrice,
        uint8 _strikePriceDecimals,
        uint256 _expiry,
        uint256 _windowSize,
        address _oracleAddress,
        address _exchangeAddress,
        address owner
    ) public ERC20(_name, _symbol) {
        require(block.timestamp < _expiry, "EXPIRED");
        require(_windowSize <= _expiry, "WINDOW_SIZE_BIGGER_THEN_EXPIRY");
        underlying = ERC20(_underlying);
        strike = ERC20(_strike);
        collateral = ERC20(_collateral);
        // require(
        //     _collateral.decimals() <= uint256(18) &&
        //         _collateral.decimals() > uint256(0),
        //     "抵押币种不是正经erc20币，小数位数大于18"
        // );
        // require(
        //     _underlying.decimals() <= uint256(18) &&
        //         underlying.decimals() > uint256(0),
        //     "标的币种不是正经erc20币，小数位数大于18"
        // );
        // require(
        //     _strikePriceDecimals <= uint256(18) &&
        //         _strikePriceDecimals > uint256(0),
        //     "价格小数位数不能大于18"
        // );

        strikePrice = _strikePrice;
        strikePriceDecimals = _strikePriceDecimals;
        expiry = _expiry;
        windowSize = _windowSize;
        exchange = IPloutozOptExchange(_exchangeAddress);
        exchangeAddress = _exchangeAddress;
        COMPOUND_ORACLE = CompoundOracleInterface(_oracleAddress);
        Weth = IWETH(exchange.Weth());
        transferOwnership(owner);
    }

    event VaultOpened(address payable vaultOwner);
    event ETHCollateralAdded(
        address payable vaultOwner,
        uint256 amount,
        address payer
    );

    event IssuedOTokens(
        address issuedTo,
        uint256 collateralAmt,
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

    // 获取vault所有者的地址
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

    // 获取vault数据
    function getVault(address payable vaultOwner)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            bool
        )
    {
        Vault storage vault = vaults[vaultOwner];
        return (
            vault.collateral,
            vault.tokensIssued,
            vault.underlying,
            vault.liquidity,
            vault.owned
        );
    }

    // 判断是否拥有vault
    function hasVault(address payable owner) public view returns (bool) {
        return vaults[owner].owned;
    }

    function openVault() internal notExpired returns (bool) {
        require(!hasVault(msg.sender), "Vault already created");

        vaults[msg.sender] = Vault(0, 0, 0, 0, true);
        vaultOwners.push(msg.sender);

        emit VaultOpened(msg.sender);
        return true;
    }

    // 是否在窗口期
    function isExerciseWindow() public view returns (bool) {
        return ((block.timestamp >= expiry.sub(windowSize)) &&
            (block.timestamp < expiry));
    }

    // 判断是否已过期
    function hasExpired() public view returns (bool) {
        return (block.timestamp >= expiry);
    }

    // 行权
    function exercise(
        uint256 tokensToExercise // wei
    ) external payable {
        uint256 tokenBalance = balanceOf(msg.sender);
        require(
            tokensToExercise <= tokenBalance,
            "insufficent tokens to exercise"
        );
        // 将eth换成weth，防止重入，行权两次
        Weth.deposit{value: msg.value}();
        for (uint256 i = 0; i < vaultOwners.length; i++) {
            address payable vaultOwner = vaultOwners[i];
            require(
                hasVault(vaultOwner),
                "CANNOT_EXERCISE_FROM_A_VAULT_THAT_DOESN'T_EXIST"
            );
            Vault storage vault = vaults[vaultOwner];
            if (tokensToExercise == 0) {
                return;
            } else if (vault.tokensIssued >= tokensToExercise) {
                _exercise(tokensToExercise, vaultOwner); // tokensToExercise wei
                return;
            } else {
                tokensToExercise = tokensToExercise.sub(vault.tokensIssued); // wei
                _exercise(vault.tokensIssued, vaultOwner);
            }
        }
        require(
            tokensToExercise == 0,
            "SPECIFIED_VAULTS_HAVE_INSUFFICIENT_COLLATERAl"
        );
    }

    function isETH(IERC20 _ierc20) public pure returns (bool) {
        return _ierc20 == IERC20(0);
    }

    // seller进行赎回清算
    function redeemVaultBalance() public {
        require(hasExpired(), "CAN'T_COLLECT_COLLATERAL_UNTIL_EXPIRY");
        require(hasVault(msg.sender), "VAULT_DOES_NOT_EXIST");

        // pay out owner their share
        Vault storage vault = vaults[msg.sender];

        // To deal with lower precision
        uint256 collateralToTransfer = vault.collateral;
        uint256 underlyingToTransfer = vault.underlying;
        uint256 liquidity = vault.liquidity;

        vault.collateral = 0;
        vault.tokensIssued = 0;
        vault.underlying = 0;
        vault.liquidity = 0;
        // 赎回uniswap流动性
        (uint256 amountToken, ) = exchange.redeemLiquidity(
            address(this),
            msg.sender,
            liquidity
        );
        transferCollateral(msg.sender, collateralToTransfer);
        transferUnderlying(msg.sender, underlyingToTransfer);
        _burn(msg.sender, amountToken);
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

    function getCollateral(address payable vaultOwner)
        internal
        view
        returns (uint256)
    {
        Vault storage vault = vaults[vaultOwner];
        return vault.collateral;
    }

    function getOTokensIssued(address payable vaultOwner)
        internal
        view
        returns (uint256)
    {
        Vault storage vault = vaults[vaultOwner];
        return vault.tokensIssued;
    }

    function _exercise(
        uint256 tokensToExercise, // wei
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

        // 1. Check sufficient underlying
        // 1.1 update underlying balances
        uint256 amtUnderlyingToPay = tokensToExercise; // wei 默认1一个token对应一个underlying
        vault.underlying = vault.underlying.add(amtUnderlyingToPay);

        // 2. Calculate Collateral to pay
        // 2.1 Payout enough collateral to get (strikePrice * oTokens) amount of collateral
        // 实际付给buyer的抵押物数量，要根据当前collateral和strike的价格计算，然后给付。即有可能给付的数量多于（strike相对于collateral涨价了）或者少于（strike相对于collateral降价了）当初的抵押量；
        uint256 amtCollateralToPay = calculateCollateralToPay(
            tokensToExercise,
            10**18
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
            uint256 underlyingAmt = amtUnderlyingToPay.mul(
                underlying.decimals() - uint256(18)
            );
            require(
                underlying.transferFrom(
                    msg.sender,
                    address(this),
                    underlyingAmt
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

    // tokensIssued wei
    function isSafe(
        uint256 collateralAmt, // wei
        uint256 tokensIssued //wei
    ) internal view returns (bool result) {
        // get price from Oracle
        uint256 collateralToEthPrice = 1;
        uint256 strikeToEthPrice = 1;

        if (collateral != strike) {
            // collateralToEthPrice = getPrice(address(collateral));
            // strikeToEthPrice = getPrice(address(strike));
        }

        // check `oTokensIssued * minCollateralizationRatio * strikePrice <= collAmt * collateralToStrikePrice` 流通期权合约的相对抵押物的价值，不能小于vault中抵押物的 1/16
        uint256 leftSideVal = tokensIssued
            .mul(minCollateralizationRatio)
            .div(10**18)
            .mul(strikePrice)
            .div(10**uint256(strikePriceDecimals)); // wei

        uint256 rightSideVal = collateralAmt.mul(collateralToEthPrice).div(
            strikeToEthPrice
        ); // wei

        result = (leftSideVal <= rightSideVal);
    }

    function maxOTokensIssuable(uint256 collateralAmt)
        public
        view
        returns (uint256)
    {
        return calculateOTokens(collateralAmt, minCollateralizationRatio);
    }

    function calculateOTokens(
        uint256 collateralAmt,
        uint256 proportion // wei
    ) internal view returns (uint256 numOptions) {
        // get price from Oracle
        uint256 collateralToEthPrice = 1;
        uint256 strikeToEthPrice = 1;
        if (!isETH(collateral)) {
            collateralAmt = collateralAmt.mul(
                10**(uint256(18) - collateral.decimals())
            ); //wei
        }
        uint256 strikePriceWei = strikePrice.mul(
            10**(uint256(18) - strikePriceDecimals)
        ); // wei
        if (collateral != strike) {
            collateralToEthPrice = getPrice(address(collateral));
            strikeToEthPrice = getPrice(address(strike));
        }

        // oTokensIssued  <= collAmt * collateralToStrikePrice / (proportion * strikePrice)
        uint256 denomVal = proportion.mul(strikePriceWei); // wei

        uint256 numeratorVal = collateralAmt.mul(collateralToEthPrice).div(
            strikeToEthPrice
        ); // wei
        numOptions = numeratorVal.div(denomVal); // wei
    }

    function calculateCollateralToPay(
        uint256 _tokens, // wei
        uint256 proportion // wei
    ) internal view returns (uint256 result) {
        // Get price from oracle
        uint256 collateralToEthPrice = 1;
        uint256 strikeToEthPrice = 1;

        // 据实际情况看来，当前所有的期权合约抵押collateral全部都是标的strike币，所以全部不满足这个条件
        if (collateral != strike) {
            // 抵押币非计价币时，需要取抵押币的对eth价格，和strike币对eth的价格；
            collateralToEthPrice = getPrice(address(collateral));
            strikeToEthPrice = getPrice(address(strike));
        }

        // collateral的数量等于oToken的数量乘以strikePrice
        result = _tokens
            .mul(strikePrice)
            .mul(proportion)
            .mul(strikeToEthPrice)
            .div(collateralToEthPrice)
            .mul(10**(uint256(18) - strikePriceDecimals)); // wei
        if (!isETH(collateral))
            result = result.mul(10**(collateral.decimals() - uint256(18))); // wei 转成币种数量
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

    // seller抵押发布期权；实际数量amtCollateral*10**collateralExp
    function createCollateralOption(
        uint256 amtCollateral // wei
    ) external payable returns (uint256 amtToCreate) {
        if (!hasVault(msg.sender)) {
            openVault();
        }

        // if (!isETH(collateral)) {
        //     amtCollateral = amtCollateral.mul(
        //         10**(uint256(18) - collateral.decimals())
        //     ); // wei
        // }
        uint256 liquidityEth = 0;
        uint256 collateralEth = 0;
        if (isETH(collateral)) {
            require(
                msg.value > amtCollateral,
                "eth amount must bigger then collateral amount."
            );
            liquidityEth = msg.value.sub(amtCollateral);
            collateralEth = amtCollateral;
        } else {
            require(msg.value > 0, "must send some eth for uniswap liquidity.");
            liquidityEth = msg.value;
        }
        require(liquidityEth > 0, "NO SUFFICIENT ETH TO ADD LIQUIDITY");

        if (isETH(collateral)) {
            // 把抵押的eth存上，还有剩余的做流动性的eth
            Weth.deposit{value: collateralEth}();
        } else {
            // 先转代币，免得付不起gas
            require(
                collateral.transferFrom(
                    msg.sender,
                    address(this),
                    amtCollateral
                ),
                "COULD NOT TRANSFER IN COLLATERAL TOKENS"
            );
        }

        Vault storage vault = vaults[msg.sender];
        vault.collateral = vault.collateral.add(amtCollateral);
        emit ETHCollateralAdded(msg.sender, msg.value, msg.sender);

        //check that we're properly collateralized to mint this number, then call _mint(address account, uint256 amount)
        require(hasVault(msg.sender), "VAULT_DOES_NOT_EXIST");

        // checks that the vault is sufficiently collateralized

        amtToCreate = amtCollateral.mul(10**uint256(strikePriceDecimals)).div(
            strikePrice
        ); // wei

        uint256 newTokensBalance = vault.tokensIssued.add(amtToCreate);
        require(isSafe(vault.collateral, newTokensBalance), "UNSAFE_TO_MINT");

        // issue the oTokens
        vault.tokensIssued = newTokensBalance;
        _mint(msg.sender, amtToCreate);
        emit IssuedOTokens(
            msg.sender,
            vault.collateral,
            amtToCreate,
            msg.sender
        );

        transfer(exchangeAddress, amtToCreate);
        (uint256 amountETH, uint256 liquidity) = exchange.addLiquidityETH{
            value: liquidityEth
        }(amtToCreate, address(this));
        vault.liquidity = vault.liquidity.add(liquidity);
        if (liquidityEth > amountETH) {
            TransferHelper.safeTransferETH(
                msg.sender,
                liquidityEth - amountETH
            );
            emit ChargeDust(msg.sender, liquidityEth - amountETH);
        }
    }

    event ChargeDust(address to, uint256 amt);

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // fallback() external payable {
    //     // to get ether from uniswap exchanges
    // }
}
