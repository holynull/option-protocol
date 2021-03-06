const { expectRevert, time } = require('@openzeppelin/test-helpers');
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

    let factory: PloutozOptFactoryInstance;

    let exchange: PloutozOptExchangeInstance;

    let optContract: PloutozOptContractInstance;

    let wethContract: WETH9Instance;

    let wethContractAddress: string;

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
    let optContractAddress: string;

    let collateralAmt: number;
    let disirePrice: number;// 期望价格 usd/张期权合约
    let collateralAmtWei: BigNumber;
    let liquidityEthWei: BigNumber;
    let tokensWei: BigNumber;

    before('测试前获取要测试的期权合约，并抵押发布合约', async () => {
        // await StringComparatorContract.new();
        factory = await PloutozOptFactoryContract.deployed();
        exchange = await PloutozOptExchangeContract.deployed();

        let supportUSDC = await factory.supportsAsset('USDC');
        let network_id = await web3.eth.net.getId();
        let usdcAddress: string = '';
        switch (network_id) {
            case 1: // mian net
                usdcAddress = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
                wethContractAddress = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';
                wethContract = await WETH9Contract.at(wethContractAddress);
                break;
            case 42: // kovan
                usdcAddress = '0x75B0622Cec14130172EaE9Cf166B92E5C112FaFF';
                wethContractAddress = '0xd0A1E359811322d97991E03f863a0C30C2cF029C';
                wethContract = await WETH9Contract.at(wethContractAddress);
                break;
            case 5777: // development
                usdcAddress = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
                wethContract = await WETH9Contract.deployed();
                break;
            case 4: // rinkeby
                usdcAddress = '0x4DBCdF9B62e891a7cec5A2568C3F4FAF9E8Abe2b';
                wethContractAddress = '0xc778417e063141139fce010982780140aa0cd5ab';
                wethContract = await WETH9Contract.at(wethContractAddress);
                break;
        }
        if (!supportUSDC) {
            await factory.addAsset('USDC', usdcAddress);
        }
        let creatRes = await factory.createOptionsContract(
            'oEthc call 400.00 2020/9/10', // name 
            'USDC', // underlying
            'ETH', // strike
            'ETH', // collateral
            '250', // strikePrice
            6, // strikePriceDecimals
            '1599719343', // expiry
            '1598344440' // windowsize
        );
        if (creatRes.logs) {
            creatRes.logs.forEach(e => {
                if (e.event === 'OptionsContractCreated') {
                    optContractAddress = e.args[0];
                }
            });
        }
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
        }
    });

    describe('期权合约创建完成', async () => {

        it('期权合约的地址不为空', async () => {
            expect(optContractAddress).not.equal('');
        });

    });

});
