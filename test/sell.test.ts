import { expect, assert } from 'chai';
import {
    PloutozOptContractContract,
    PloutozOptContractInstance,
    PloutozOptFactoryContract,
    PloutozOptFactoryInstance,
    PloutozOracleContract,
    PloutozOracleInstance,
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
    let optContractAddress: string = '0xEa7C1089c7A61ddaef7062eC6FFb2fdEfeE60Ed3';

    let sellAmtWei: string;

    before('测试前获取要测试的期权合约，并抵押发布合约', async () => {
        // await StringComparatorContract.new();

        if (optContractAddress) {
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

            sellAmtWei = web3.utils.toWei('3', 'ether');
            let premiumEthWei = await exchange.premiumReceived(optContractAddress, sellAmtWei);
            premiumEthWei = new BigNumber(premiumEthWei.toString());
            console.log('Premium eth: ' + premiumEthWei.toFormat());
            let usdcToEthPriceWei = await optContract.getPrice(underlying);
            usdcToEthPriceWei = new BigNumber(usdcToEthPriceWei.toString());
            let buyPriceUsd = premiumEthWei.div(new BigNumber(sellAmtWei)).div(usdcToEthPriceWei).multipliedBy(new BigNumber(10).exponentiatedBy(18));
            console.log('Sell price: $' + buyPriceUsd.toFixed(4, BigNumber.ROUND_DOWN));
            await optContract.approve(exchangeAddress, sellAmtWei, { from: accounts[1] });
            await exchange.sellOTokens(optContractAddress, sellAmtWei, { from: accounts[1] });
        }
    });


    describe('buyer售卖期权后', async () => {

        it('检查buyer的期权余额', async () => {
            let optBalanceWei = await optContract.balanceOf(accounts[1]);
            console.log('Buyer opt balance: ' + new BigNumber(optBalanceWei.toString()).toFormat());
            // expect(new BigNumber(buyAmtWei).toFormat()).equal(new BigNumber(optBalanceWei.toString()).toFormat());
        });
    });

});
