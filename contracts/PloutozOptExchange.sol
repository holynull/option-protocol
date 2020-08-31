pragma solidity >=0.6.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./lib/UniswapV2Library.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PloutozOptExchange is Ownable {
    uint256 constant LARGE_BLOCK_SIZE = 1651753129000;
    uint256 constant LARGE_APPROVAL_NUMBER = 10**30;

    address public UNISWAP_FACTORY;
    address private WETH;
    IUniswapV2Router01 public uniswapRouter01;
    address router01Address;
    IUniswapV2Router02 public uniswapRouter02;
    address router02Address;

    // constructor(
    //     address _uniswapFactory,
    //     address _uniswapRouter01,
    //     address _uniswapRouter02
    // ) public {
    //     UNISWAP_FACTORY = _uniswapFactory;
    //     uniswapRouter01 = IUniswapV2Router01(_uniswapRouter01);
    //     uniswapRouter02 = IUniswapV2Router02(_uniswapRouter02);
    //     WETH = uniswapRouter02.WETH();
    // }

    constructor(
        address _uniswapFactory,
        address _uniswapRouter01,
        address _uniswapRouter02,
        address _wethAddress
    ) public Ownable() {
        UNISWAP_FACTORY = _uniswapFactory;
        router01Address = _uniswapRouter01;
        router02Address = _uniswapRouter02;
        uniswapRouter01 = IUniswapV2Router01(_uniswapRouter01);
        uniswapRouter02 = IUniswapV2Router02(_uniswapRouter02);
        if (_wethAddress == address(0)) {
            WETH = uniswapRouter02.WETH();
        } else {
            WETH = _wethAddress;
        }
    }

    /*** Events ***/
    event SellOTokens(
        address seller,
        address payable receiver,
        address oTokenAddress,
        address payoutTokenAddress,
        uint256 oTokensToSell
    );
    event BuyOTokens(
        address buyer,
        address payable receiver,
        address oTokenAddress,
        address paymentTokenAddress,
        uint256 oTokensToBuy,
        uint256 premiumPaid
    );

    event AddUniswapLiquidity(
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    function Weth() external view returns (address addr) {
        addr = WETH;
    }

    function sellOTokens(address oTokenAddress, uint256 oTokensToSell)
        external
        returns (uint256[] memory amounts)
    {
        IERC20 oToken = IERC20(oTokenAddress);
        require(!isETH(oToken), "CAN ONLY SELL OTOKENS");
        require(
            oToken.transferFrom(msg.sender, address(this), oTokensToSell), // msg.sender先向交易所转帐
            "TRANSFER OTOKENS FIALED"
        );
        // IUniswapV2Pair pair = IUniswapV2Pair(
        //     UniswapV2Library.pairFor(
        //         UNISWAP_FACTORY,
        //         address(oToken),
        //         address(WETH)
        //     )
        // );
        require(
            oToken.approve(address(uniswapRouter02), oTokensToSell),
            "APPROVE FAILED"
        );
        // amountOutMin must be retrieved from an oracle of some kind
        address[] memory path = new address[](2);
        path[0] = address(oToken);
        path[1] = WETH;
        amounts = uniswapRouter02.swapExactTokensForETH(
            oTokensToSell,
            1,
            path,
            msg.sender,
            block.timestamp
        );
        TransferHelper.safeTransferETH(msg.sender, amounts[amounts.length - 1]);
        emit SellOTokens(
            msg.sender,
            msg.sender,
            oTokenAddress,
            WETH,
            oTokensToSell
        );
    }

    function buyOTokens(address oTokenAddress, uint256 oTokensToBuy)
        external
        payable
        returns (uint256[] memory amounts)
    {
        IERC20 oToken = IERC20(oTokenAddress);
        require(!isETH(oToken), "CAN ONLY SELL OTOKENS");
        // amountOutMin must be retrieved from an oracle of some kind
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(oToken);
        amounts = uniswapRouter02.swapETHForExactTokens{value: msg.value}(
            oTokensToBuy,
            path,
            msg.sender,
            block.timestamp
        );
        if (msg.value > amounts[0])
            TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    function addLiquidityETH(
        uint256 amtToCreate,
        address optContractAddress,
        address receiver
    ) public payable returns (uint256 amountETH, uint256 liquidity) {
        IERC20 optToken = IERC20(optContractAddress);
        optToken.approve(router02Address, amtToCreate);
        // (, amountETH, liquidity) = uniswapRouter02.addLiquidityETH{
        //     value: msg.value
        // }(optContractAddress, amtToCreate, 1, 1, receiver, block.timestamp);
        if (liquidity > amountETH) {
            TransferHelper.safeTransferETH(msg.sender, liquidity - amountETH);
        }
        emit AddUniswapLiquidity(amtToCreate, msg.value, liquidity);
    }

    // 能卖多少eth
    function premiumReceived(address oTokenAddress, uint256 oTokensToSell)
        public
        view
        returns (uint256 amt)
    {
        address[] memory path = new address[](2);
        path[0] = oTokenAddress;
        path[1] = WETH;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(
            address(UNISWAP_FACTORY),
            oTokensToSell,
            path
        );
        amt = amounts[amounts.length - 1];
    }

    // 能买多少出来
    function premiumToPay(address oTokenAddress, uint256 oTokensToBuy)
        public
        view
        returns (uint256 amts)
    {
        address[] memory path = new address[](2);
        path[1] = oTokenAddress;
        path[0] = WETH;
        uint256[] memory amounts = UniswapV2Library.getAmountsIn(
            address(UNISWAP_FACTORY),
            oTokensToBuy,
            path
        );
        amts = amounts[0];
    }

    function isETH(IERC20 _ierc20) internal pure returns (bool) {
        return _ierc20 == IERC20(0);
    }

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    fallback() external payable {
        // to get ether from uniswap exchanges
    }
}
