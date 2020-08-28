pragma solidity >=0.6.0;

import "./PloutozOptContract.sol";
import "./lib/StringComparator.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";

contract PloutozOptFactory is OwnableUpgradeSafe {
    using StringComparator for string;

    // keys saved in front-end -- look at the docs if needed
    mapping(string => ERC20UpgradeSafe) public tokens;
    address[] public optionsContracts;

    // The contract which interfaces with the exchange
    address public oracleAddress;

    address uniswapRouter02;

    event OptionsContractCreated(address addr);
    event AssetAdded(string indexed asset, address indexed addr);
    event AssetChanged(string indexed asset, address indexed addr);
    event AssetDeleted(string indexed asset);

    // constructor(address _oracleAddress, address _uniswapRouter02) public {
    //     oracleAddress = _oracleAddress;
    //     uniswapRouter02 = _uniswapRouter02;
    // }

    function initialize(address _oracleAddress, address _uniswapRouter02)
        public
        initializer
    {
        oracleAddress = _oracleAddress;
        uniswapRouter02 = _uniswapRouter02;
        __Ownable_init();
    }

    function createOptionsContract(
        string memory _symbol,
        string memory _name,
        string memory _underlyingType,
        string memory _strikeAsset,
        string memory _collateralType,
        uint256 _strikePrice,
        uint8 _strikePriceDecimals,
        uint256 _expiry,
        uint256 _windowSize
    ) public returns (address optionContractAddr) {
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

        PloutozOptContract optionsContract = new PloutozOptContract(
            _symbol,
            _name
        );

        optionsContract.setOption(
            tokens[_collateralType],
            tokens[_underlyingType],
            tokens[_strikeAsset],
            _strikePrice,
            _strikePriceDecimals,
            _expiry,
            _windowSize,
            oracleAddress,
            uniswapRouter02
        );

        optionsContracts.push(address(optionsContract));
        emit OptionsContractCreated(address(optionsContract));

        // Set the owner for the options contract.
        optionsContract.transferOwnership(owner());

        optionContractAddr = address(optionsContract);
    }

    function getNumberOfOptionsContracts() public view returns (uint256) {
        return optionsContracts.length;
    }

    function addAsset(string memory _asset, address _addr) public onlyOwner {
        require(!supportsAsset(_asset), "ASSET_ALREADY_ADDED");
        require(_addr != address(0), "CANNOT SET TO ADDRESS(0)");

        tokens[_asset] = ERC20UpgradeSafe(_addr);
        emit AssetAdded(_asset, _addr);
    }

    function changeAsset(string memory _asset, address _addr) public onlyOwner {
        require(
            tokens[_asset] != ERC20UpgradeSafe(0),
            "TRYING_TO_REPLACE_A_NON-EXISTENT_ASSET"
        );
        require(_addr != address(0), "CANNOT_SET_TO_ADDRESS(0)");

        tokens[_asset] = ERC20UpgradeSafe(_addr);
        emit AssetChanged(_asset, _addr);
    }

    function deleteAsset(string memory _asset) public onlyOwner {
        require(
            tokens[_asset] != ERC20UpgradeSafe(0),
            "TRYING_TO_DELETE_A_NON-EXISTENT_ASSET"
        );

        tokens[_asset] = ERC20UpgradeSafe(0);
        emit AssetDeleted(_asset);
    }

    function supportsAsset(string memory _asset) public view returns (bool) {
        if (_asset.compareStrings("ETH")) {
            return true;
        }

        return tokens[_asset] != ERC20UpgradeSafe(0);
    }

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    fallback() external payable {
        // to get ether from uniswap exchanges
    }
}
