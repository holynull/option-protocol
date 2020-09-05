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
    let optContractAddress: string = '0x8b5Eb5BdF6556265AaaB77028d71135Eac57455b';

    let collateralAmt: number;
    let disirePrice: number;// 期望价格 usd/张期权合约
    let collateralAmtWei: BigNumber;
    let liquidityEthWei: BigNumber;
    let tokensWei: BigNumber;
    let balanceBeforRedeem;
    let balanceAfterRedeem;

    before('测试前获取要测试的期权合约，并抵押发布合约', async () => {

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

        let balanceWei = await optContract.balanceOf(accounts[1]);

        await optContract.exercise(balanceWei.toString(), { from: accounts[1] });

    });

    describe('buyer行权后后，检查数据', async () => {
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
