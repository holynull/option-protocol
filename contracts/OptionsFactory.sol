pragma solidity 0.6.0;

import "./OptionsContract.sol";
import "./oToken.sol";
import "./OptionsUtils.sol";
import "./lib/StringComparator.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OptionsFactory is Ownable {
    using StringComparator for string;

    // keys saved in front-end -- look at the docs if needed
    mapping(string => IERC20) public tokens;
    address[] public optionsContracts;

    // The contract which interfaces with the exchange
    OptionsExchange public optionsExchange;
    address public oracleAddress;

    event OptionsContractCreated(address addr);
    event AssetAdded(string indexed asset, address indexed addr);
    event AssetChanged(string indexed asset, address indexed addr);
    event AssetDeleted(string indexed asset);

    constructor(OptionsExchange _optionsExchangeAddr, address _oracleAddress)
        public
    {
        optionsExchange = OptionsExchange(_optionsExchangeAddr);
        oracleAddress = _oracleAddress;
    }

    function createOptionsContract(
        string memory _collateralType,
        int32 _collateralExp,
        string memory _underlyingType,
        int32 _underlyingExp,
        uint256 _strikePrice,
        int32 _strikeExp,
        string memory _strikeAsset,
        uint256 _expiry,
        uint256 _windowSize,
        uint8 _decimals,
        address _weth
    ) public returns (address) {
        require(_expiry > block.timestamp, "WRONG_EXPIRY");
        require(_windowSize <= _expiry, "INVALID_WINDOWSIZE");
        require(
            supportsAsset(_collateralType),
            "COLLATERAL_TYPE_NOT_SUPPORTED"
        );
        require(
            supportsAsset(_underlyingType),
            "UNDERLYING_TYPE_NOT_SUPPORTED"
        );
        require(supportsAsset(_strikeAsset), "STRIKE_ASSET_TYPE_NOT_SUPPORTED");

        OptionsContract optionsContract = new OptionsContract(
            tokens[_collateralType],
            _collateralExp,
            tokens[_underlyingType],
            _underlyingExp,
            _strikePrice,
            _strikeExp,
            tokens[_strikeAsset],
            _expiry,
            optionsExchange,
            oracleAddress,
            _windowSize,
            _decimals,
            _weth
        );

        optionsContracts.push(address(optionsContract));
        emit OptionsContractCreated(address(optionsContract));

        // Set the owner for the options contract.
        optionsContract.transferOwnership(owner());

        return address(optionsContract);
    }

    function getNumberOfOptionsContracts() public view returns (uint256) {
        return optionsContracts.length;
    }

    function addAsset(string memory _asset, address _addr) public onlyOwner {
        require(!supportsAsset(_asset), "ASSET_ALREADY_ADDED");
        require(_addr != address(0), "Cannot set to address(0)");

        tokens[_asset] = IERC20(_addr);
        emit AssetAdded(_asset, _addr);
    }

    function changeAsset(string memory _asset, address _addr) public onlyOwner {
        require(
            tokens[_asset] != IERC20(0),
            "TRYING_TO_REPLACE_A_NON-EXISTENT_ASSET"
        );
        require(_addr != address(0), "CANNOT_SET_TO_ADDRESS(0)");

        tokens[_asset] = IERC20(_addr);
        emit AssetChanged(_asset, _addr);
    }

    function deleteAsset(string memory _asset) public onlyOwner {
        require(
            tokens[_asset] != IERC20(0),
            "TRYING_TO_DELETE_A_NON-EXISTENT_ASSET"
        );

        tokens[_asset] = IERC20(0);
        emit AssetDeleted(_asset);
    }

    function supportsAsset(string memory _asset) public view returns (bool) {
        if (_asset.compareStrings("ETH")) {
            return true;
        }

        return tokens[_asset] != IERC20(0);
    }
}
