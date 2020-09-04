import { expect, assert } from 'chai';
import {
    PloutozOptContractContract,
    PloutozOptContractInstance,
    PloutozOptFactoryContract,
    PloutozOptExchangeContract,
    PloutozOptExchangeInstance,
    WETH9Contract,
    WETH9Instance,
} from '../build/types/truffle-types';
// Load compiled artifacts
const PloutozOptContract: PloutozOptContractContract = artifacts.require('PloutozOptContract.sol');
const PloutozOptFactoryContract: PloutozOptFactoryContract = artifacts.require('PloutozOptFactory.sol');
const PloutozOptExchangeContract: PloutozOptExchangeContract = artifacts.require('PloutozOptExchange.sol');
const WETH9Contract: WETH9Contract = artifacts.require('WETH9.sol');
import { BigNumber } from 'bignumber.js';

contract('期权合约 Call ETH/USDC', async accounts => {

    let exchange: PloutozOptExchangeInstance;

    let optContract: PloutozOptContractInstance;

    let wethContract: WETH9Instance;

    let decimal: BigNumber;
    let symbol: string;
    let name: string;
    let underlying: string;
    let strike: string;
    let collateral: string;
    let strikePrice: BigNumber;
    let strikePriceDecimals: BigNumber;
    let expiry: BigNumber;
    let windwosize: BigNumber;
    let exchangeAddress: string;
    let optContractAddress: string = '0x8b5Eb5BdF6556265AaaB77028d71135Eac57455b';
    let totalSupplyWei: BigNumber;

    let collateralAmt: number;
    let disirePrice: number;// 期望价格 usd/张期权合约
    let collateralAmtWei: BigNumber;
    let liquidityEthWei: BigNumber;
    let tokensWei: BigNumber;
    let wethContractAddress: string;
    let wethBalanceWei: BigNumber;
    let liquidityWei: BigNumber;

    before('测试前获取要测试的期权合约，并抵押发布合约', async () => {
        let network_id = await web3.eth.net.getId();
        switch (network_id) {
            case 1: // mian net
                wethContractAddress = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';
                wethContract = await WETH9Contract.at(wethContractAddress);
                break;
            case 42: // kovan
                wethContractAddress = '0xd0A1E359811322d97991E03f863a0C30C2cF029C';
                wethContract = await WETH9Contract.at(wethContractAddress);
                break;
            case 5777: // development
                wethContract = await WETH9Contract.deployed();
                break;
            case 4: // rinkeby
                wethContractAddress = '0xc778417e063141139fce010982780140aa0cd5ab';
                wethContract = await WETH9Contract.at(wethContractAddress);
                break;
        }
        optContract = await PloutozOptContract.at(optContractAddress);
        console.log('address: ' + optContract.address);
        decimal = await optContract.decimals();
        console.log('decimals: ' + decimal);
        symbol = await optContract.symbol();
        console.log('symbol: ' + symbol);
        name = await optContract.name();
        console.log('name: ' + name);
        underlying = await optContract.underlying();
        console.log('underlying address: ' + underlying);
        strike = await optContract.strike();
        console.log('strike address: ' + strike);
        collateral = await optContract.collateral();
        console.log('collateral: ' + collateral);
        strikePrice = await (await optContract.strikePrice());
        console.log('strike Price: ' + new BigNumber(strikePrice.toString()).toFormat());
        strikePriceDecimals = await optContract.strikePriceDecimals();
        console.log('strike Price Decimals: ' + strikePriceDecimals);
        expiry = await optContract.expiry();
        console.log('expiry: ' + new Date(Number(expiry) * 1000));
        windwosize = await optContract.windowSize();
        console.log('window size: ' + new Date(Number(windwosize) * 1000));
        exchangeAddress = await optContract.exchange();
        console.log('exchange is at: ' + exchangeAddress);
        exchange = await PloutozOptExchangeContract.at(exchangeAddress);

        collateralAmt = 0.01; // 打算抵押eth的数量
        collateralAmtWei = new BigNumber(web3.utils.toWei(String(collateralAmt), 'ether'));
        tokensWei = collateralAmtWei.multipliedBy(new BigNumber(10).exponentiatedBy(strikePriceDecimals)).div(strikePrice);
        disirePrice = 0.1; // 期望价格 usd/张期权合约, $1.30
        let underlyingEthPriceWei: BigNumber = new BigNumber(await optContract.getPrice(underlying));
        console.log('underlyingEthPriceWei: ' + underlyingEthPriceWei.toFormat());
        liquidityEthWei = tokensWei.multipliedBy(new BigNumber(10).exponentiatedBy(-18)).multipliedBy(disirePrice).multipliedBy(underlyingEthPriceWei);

        console.log('collateralAmtWei: ' + collateralAmtWei.toFormat());
        console.log('liquidityEthWei: ' + liquidityEthWei.toFormat());
        let totalEthAmtWei = collateralAmtWei.plus(liquidityEthWei);
        console.log('totalEthAmtWei: ' + totalEthAmtWei.toFormat());
        totalSupplyWei = new BigNumber((await optContract.totalSupply()).toString());
        console.log('TotalSupply: ' + totalSupplyWei.toFormat());
        wethBalanceWei = new BigNumber((await wethContract.balanceOf(optContractAddress)).toString());
        console.log('Weth balance: ' + wethBalanceWei.toFormat());
        // 抵押发布合约
        await optContract.collateralIssueOption(collateralAmtWei.toFixed(0, BigNumber.ROUND_DOWN), { value: totalEthAmtWei.toFixed(0, BigNumber.ROUND_DOWN) });

    });

    describe('抵押发布期权合约以后，检查数据', async () => {

        it('期权合约的totalSupply应该等于发布的期权数量', async () => {
            // let tokens = await optContract.balanceOf(exchange.address); // 生成期权合约的数量，这些期权合约将被转给exchange
            let totalSupply = await optContract.totalSupply();
            totalSupply = new BigNumber(totalSupply.toString()).minus(totalSupplyWei);
            // expect(tokens.toString()).equal(tokensWei.toFixed(0, BigNumber.ROUND_DOWN));
            expect(totalSupply.toFixed(0, BigNumber.ROUND_DOWN)).equal(tokensWei.toFixed(0, BigNumber.ROUND_DOWN));
        });
        it('期权合约上eth的数量应该等于0', async () => {
            let optContractEthBalance = await web3.eth.getBalance(optContractAddress); // 期权合约上的eth的数量，应该为0
            expect(optContractEthBalance).equal('0');
        });
        it('期权合约上weth的数量应该等于抵押的eth的数量', async () => {
            let optContractWETHBalance = await wethContract.balanceOf(optContractAddress); // 期权合约上抵押的weth数量是否正确
            optContractWETHBalance = new BigNumber(optContractWETHBalance.toString()).minus(wethBalanceWei);
            expect(optContractWETHBalance.toFixed(0, BigNumber.ROUND_DOWN)).equal(collateralAmtWei.toFixed(0, BigNumber.ROUND_DOWN));
        });
        it('托管的liquidity应该等于opt合约上的liquidity余额', async () => {
            // 流动性在exchange上托管
            let liquidity = await exchange.getLiquidityBalance(exchangeAddress, optContractAddress);
            console.log('liquidity: ' + new BigNumber(liquidity).toFormat());
            let vault: any = await optContract.getVault(accounts[0]);
            let vLiquidity = new BigNumber(vault[3].toString());
            // expect(vLiquidity.comparedTo(liquidity) === 0).equal(true);
        });
        it('保险库抵押的数量等于抵押数量', async () => {
            let arr = await optContract.getVault(accounts[0]);
            let vCollateralWei = arr[0].toString();
            let vTokenIssueWei = arr[1].toString();
            let vUnderlyingWei = arr[2].toString();
            let vLiquidityWei = arr[3].toString();
            console.log('vault.collateral: ' + vCollateralWei);
            console.log('vault.tokenIssued: ' + vTokenIssueWei);
            console.log('vault.underlying: ' + vUnderlyingWei);
            console.log('vault.liquidity: ' + vLiquidityWei);
            // expect(vCollateralWei).equal(collateralAmtWei.toFixed());
            // expect(vTokenIssueWei).equal(tokensWei.toFixed());
            // expect(vUnderlyingWei).equal('0');
        });
    });
});
