const { expectRevert, time } = require('@openzeppelin/test-helpers');
import { expect, assert } from 'chai';
import {
    PloutozOptContractContract,
    PloutozOptContractInstance,
    PloutozOptFactoryContract,
    PloutozOptFactoryInstance,
    PloutozOracleContract,
    PloutozOptExchangeContract,
    PloutozOptExchangeInstance,
    WETH9Contract,
    WETH9Instance,
} from '../build/types/truffle-types';
// Load compiled artifacts
const PloutozOptContract: PloutozOptContractContract = artifacts.require('PloutozOptContract.sol');
const PloutozOptFactoryContract: PloutozOptFactoryContract = artifacts.require('PloutozOptFactory.sol');
const PloutozOracleContract: PloutozOracleContract = artifacts.require('PloutozOracle.sol');
const PloutozOptExchangeContract: PloutozOptExchangeContract = artifacts.require('PloutozOptExchange.sol');
const WETH9Contract: WETH9Contract = artifacts.require('WETH9.sol');
import { BigNumber } from 'bignumber.js';

contract('期权合约 Call ETH/USDC', async accounts => {

    let exchange: PloutozOptExchangeInstance;

    let optContract: PloutozOptContractInstance;

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
    let optContractAddress: string = '0xEa7C1089c7A61ddaef7062eC6FFb2fdEfeE60Ed3';

    let collateralAmt: number;
    let disirePrice: number;// 期望价格 usd/张期权合约
    let collateralAmtWei: BigNumber;
    let liquidityEthWei: BigNumber;
    let tokensWei: BigNumber;
    let balanceBeforRedeem;
    let balanceAfterRedeem;

    before('测试前获取要测试的期权合约，并抵押发布合约', async () => {
        exchange = await PloutozOptExchangeContract.deployed();

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

        balanceBeforRedeem = new BigNumber(await web3.eth.getBalance(accounts[0]));
        console.log('balanceBeforRedeem: ' + balanceBeforRedeem.toFormat());

        await optContract.liquidateVaultBalance();

    });

    describe('seller赎回后，检查数据', async () => {

        it('赎回流动性后的余额', async () => {
            balanceAfterRedeem = new BigNumber(await web3.eth.getBalance(accounts[0]));
            console.log('balanceBeforRedeem: ' + balanceAfterRedeem.toFormat());
        });
        it('赎回后，exchange上的liquidity余额为0', async () => {
            let liquidity = await exchange.getLiquidityBalance(exchangeAddress, optContractAddress);
            expect(liquidity.toString()).equal('0');
        });

        it('赎回后，underlying数值', async () => {
            // todo：
        });
    });
});
