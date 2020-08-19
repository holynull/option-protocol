pragma solidity 0.6.0;

import "./lib/CompoundOracleInterface.sol";
import "./OptionsUtils.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OptionsExchange {
    uint256 constant LARGE_BLOCK_SIZE = 1651753129000;
    uint256 constant LARGE_APPROVAL_NUMBER = 10**30;

    address public UNISWAP_FACTORY;
    IUniswapV2Router01 public UniswapRouter01;
    IUniswapV2Router02 public UniswapRouter02;

    constructor(
        address _uniswapFactory,
        address _uniswapRouter01,
        address _uniswapRouter02
    ) public {
        UNISWAP_FACTORY = _uniswapFactory;
        uniswapRouter01 = IUniswapV2Router01(_uniswapRouter01);
        uniswapRouter02 = IUniswapV2Router02(_uniswapRouter02);
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
        address seller,
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    /**
     * @notice This function sells oTokens on Uniswap and sends back payoutTokens to the receiver
     * @param receiver The address to send the payout tokens back to
     * @param oTokenAddress The address of the oToken to sell
     * @param payoutTokenAddress The address of the token to receive the premiums in
     * @param oTokensToSell The number of oTokens to sell
     */
    function sellOTokens(address oTokenAddress, uint256 oTokensToSell)
        external
        returns (uint256[] amounts)
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
        //         address(UniswapRouter02.WETH())
        //     )
        // );
        require(
            oToken.approve(address(UniswapRouter02), oTokensToSell),
            "APPROVE FAILED"
        );
        // amountOutMin must be retrieved from an oracle of some kind
        address[] memory path = new address[](2);
        path[0] = address(oToken);
        path[1] = UniswapV2Router02.WETH();
        uint256[] amounts = UniswapV2Router02.swapExactTokensForETH(
            oTokensToSell,
            1,
            path,
            receiver,
            block.timestamp
        );
        TransferHelper.safeTransferETH(msg.sender, amts[amts.length - 1]);
        emit SellOTokens(
            msg.sender,
            receiver,
            oTokenAddress,
            payoutTokenAddress,
            oTokensToSell
        );
    }

    /**
     * @notice This function buys oTokens on Uniswap and using paymentTokens from the receiver
     * @param receiver The address to send the oTokens back to
     * @param oTokenAddress The address of the oToken to buy
     * @param paymentTokenAddress The address of the token to pay the premiums in
     * @param oTokensToBuy The number of oTokens to buy
     */
    function buyOTokens(address oTokenAddress, uint256 oTokensToBuy)
        external
        payable
        returns (uint256[] memory amts)
    {
        IERC20 oToken = IERC20(oTokenAddress);
        require(!isETH(oToken), "CAN ONLY SELL OTOKENS");
        // amountOutMin must be retrieved from an oracle of some kind
        address[] memory path = new address[](2);
        path[0] = UniswapV2Router02.WETH();
        path[1] = address(oToken);
        amounts = UniswapV2Router02.swapETHForExactTokens{value: msg.value}(
            oTokensToBuy,
            path,
            msg.sender,
            block.timestamp
        );
        if (msg.value > amounts[0])
            TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    /**
     * @notice This function calculates the amount of premiums that the seller
     * will receive if they sold oTokens on Uniswap
     * @param oTokenAddress The address of the oToken to sell
     * @param payoutTokenAddress The address of the token to receive the premiums in
     * @param oTokensToSell The number of oTokens to sell
     */
    function premiumReceived(
        address oTokenAddress,
        address payoutTokenAddress,
        uint256 oTokensToSell
    ) public view returns (uint256) {
        // get the amount of ETH that will be paid out if oTokensToSell is sold.
        UniswapExchangeInterface oTokenExchange = getExchange(oTokenAddress);
        uint256 ethReceived = oTokenExchange.getTokenToEthInputPrice(
            oTokensToSell
        );

        if (!isETH(IERC20(payoutTokenAddress))) {
            // get the amount of payout tokens that will be received if the ethRecieved is sold.
            UniswapExchangeInterface payoutExchange = getExchange(
                payoutTokenAddress
            );
            return payoutExchange.getEthToTokenInputPrice(ethReceived);
        }
        return ethReceived;
    }

    /**
     * @notice This function calculates the premiums to be paid if a buyer wants to
     * buy oTokens on Uniswap
     * @param oTokenAddress The address of the oToken to buy
     * @param paymentTokenAddress The address of the token to pay the premiums in
     * @param oTokensToBuy The number of oTokens to buy
     */
    function premiumToPay(
        address oTokenAddress,
        address paymentTokenAddress,
        uint256 oTokensToBuy
    ) public view returns (uint256) {
        // get the amount of ETH that needs to be paid for oTokensToBuy.
        UniswapExchangeInterface oTokenExchange = getExchange(oTokenAddress);
        // 先计算otoken需要多少eth
        uint256 ethToPay = oTokenExchange.getEthToTokenOutputPrice(
            oTokensToBuy
        );

        if (!isETH(IERC20(paymentTokenAddress))) {
            // 如果付款token非eth，再计算上面的eth能兑换多少付款token
            // get the amount of paymentTokens that needs to be paid to get the desired ethToPay.
            UniswapExchangeInterface paymentTokenExchange = getExchange(
                paymentTokenAddress
            );
            return paymentTokenExchange.getTokenToEthOutputPrice(ethToPay);
        }

        return ethToPay;
    }

    function uniswapSellOToken(
        IERC20 oToken,
        uint256 _amt,
        address payable _transferTo
    ) internal returns (uint256) {
        require(!isETH(oToken), "CAN ONLY SELL OTOKENS");
        require(
            oToken.approve(address(UniswapV2Router02), _amt),
            "APPROVE FAILED"
        );
        // amountOutMin must be retrieved from an oracle of some kind
        address[] memory path = new address[](2);
        path[0] = address(oToken);
        path[1] = UniswapV2Router02.WETH();
        amts = UniswapV2Router02.swapExactTokensForETH(
            _amt,
            1,
            path,
            _transferTo,
            block.timestamp
        );
        return amts[amts.length - 1];
    }

    function uniswapBuyOToken(
        IERC20 oToken, // 期权合约token
        uint256 _amt, // 购买数量
        address payable _transferTo // 购买者的地址
    ) public returns (uint256) {}

    function getExchange(address _token)
        internal
        view
        returns (UniswapExchangeInterface)
    {
        UniswapExchangeInterface exchange = UniswapExchangeInterface(
            UNISWAP_FACTORY.getExchange(_token)
        );

        if (address(exchange) == address(0)) {
            revert("No payout exchange");
        }

        return exchange;
    }

    function isETH(IERC20 _ierc20) internal pure returns (bool) {
        return _ierc20 == IERC20(0);
    }

    function() external payable {
        // to get ether from uniswap exchanges
    }
}
