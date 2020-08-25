pragma solidity >=0.6.0;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "./lib/CTokenInterface.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

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

contract PloutozOracle is OwnableUpgradeSafe {
    using SafeMath for uint256;

    mapping(address => bool) isCToken;
    mapping(address => address) assetToCTokens;
    address cETH;

    // The Oracle used for the contract
    CompoundOracleInterface public PriceOracle;

    function initialize(address _oracleAddress) public initializer {
        __Ownable_init();
        PriceOracle = CompoundOracleInterface(_oracleAddress);
        // Mainnet
        // address cBAT = 0x6C8c6b02E7b2BE14d4fA6022Dfd6d75921D90E4E;
        // address cDAI = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;
        // cETH = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
        // address cREP = 0x158079Ee67Fce2f58472A96584A73C7Ab9AC95c1;
        // address cUSDC = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;
        // address cWBTC = 0xC11b1268C1A384e55C48c2391d8d480264A3A7F4;
        // address cZRX = 0xB3319f5D18Bc0D84dD1b4825Dcde5d5f7266d407;

        // address BAT = 0x0D8775F648430679A709E98d2b0Cb6250d2887EF;
        // address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        // address REP = 0x1985365e9f78359a9B6AD760e32412f4a445E862;
        // address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        // address WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        // address ZRX = 0xE41d2489571d322189246DaFA5ebDe1F4699F498;

        // Rinkeby Addresses
        address cBAT = 0xEBf1A11532b93a529b5bC942B4bAA98647913002;
        address cDAI = 0x6D7F0754FFeb405d23C51CE938289d4835bE3b14;
        cETH = 0xd6801a1DfFCd0a410336Ef88DeF4320D6DF1883e;
        address cREP = 0xEBe09eB3411D18F4FF8D859e096C533CAC5c6B60;
        address cUSDC = 0x5B281A6DdA0B271e91ae35DE655Ad301C976edb1;
        address cWBTC = 0x0014F450B8Ae7708593F4A46F8fa6E5D50620F96;
        address cZRX = 0x52201ff1720134bBbBB2f6BC97Bf3715490EC19B;

        address BAT = 0xbF7A7169562078c96f0eC1A8aFD6aE50f12e5A99;
        address DAI = 0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa;
        address REP = 0x6e894660985207feb7cf89Faf048998c71E8EE89;
        address USDC = 0x4DBCdF9B62e891a7cec5A2568C3F4FAF9E8Abe2b;
        address WBTC = 0x577D296678535e4903D59A4C929B718e1D575e0A;
        address ZRX = 0xddea378A6dDC8AfeC82C36E9b0078826bf9e68B6;

        isCToken[cBAT] = true;
        isCToken[cDAI] = true;
        isCToken[cETH] = true;
        isCToken[cREP] = true;
        isCToken[cWBTC] = true;
        isCToken[cUSDC] = true;
        isCToken[cZRX] = true;

        assetToCTokens[BAT] = cBAT;
        assetToCTokens[DAI] = cDAI;
        assetToCTokens[REP] = cREP;
        assetToCTokens[WBTC] = cWBTC;
        assetToCTokens[USDC] = cUSDC;
        assetToCTokens[ZRX] = cZRX;
    }

    function isCETH(address asset) public view returns (bool) {
        return asset == cETH;
    }

    function getPrice(address asset) public view returns (uint256) {
        if (asset == address(0)) {
            return (10**18);
        } else {
            if (isCToken[asset]) {
                // 1. cTokens
                CTokenInterface cToken = CTokenInterface(asset);
                uint256 exchangeRate = cToken.exchangeRateStored();

                if (isCETH(asset)) {
                    uint256 numerator = 10**46;
                    return numerator.div(exchangeRate);
                }

                address underlyingAddress = cToken.underlying();
                uint256 decimalsOfUnderlying = ERC20UpgradeSafe(
                    underlyingAddress
                )
                    .decimals();
                uint256 maxExponent = 10;
                uint256 exponent = maxExponent.add(decimalsOfUnderlying);

                // cTokenPriceInETH = underlying price in ETH * (cToken : underlying exchange rate)
                return
                    getPriceUnderlying(underlyingAddress).mul(exchangeRate).div(
                        10**exponent
                    );
            } else if (assetToCTokens[asset] != address(0)) {
                //2. Underlying Tokens that Compound lists
                return getPriceUnderlying(asset);
            }
            return 0;
        }
    }

    function getPriceUnderlying(address asset) internal view returns (uint256) {
        uint256 EthToAssetPrice = PriceOracle.getUnderlyingPrice(
            IERC20(assetToCTokens[asset])
        );
        uint256 decimalsOfAsset = ERC20UpgradeSafe(asset).decimals();
        uint256 maxExponent = 18;
        uint256 exponent = maxExponent.sub(decimalsOfAsset);
        return EthToAssetPrice.div(10**exponent);
    }
}
