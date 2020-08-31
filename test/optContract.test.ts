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
const truffleAssert = require('truffle-assertions');
const Web3Utils = require('web3-utils');
import { BigNumber } from 'bignumber.js';
import { getUnixTime, addMonths, addSeconds, fromUnixTime } from 'date-fns';

contract('期权合约 Call ETH/USDC', async accounts => {
    const creatorAddress = accounts[0];
    const firstOwnerAddress = accounts[1];

    // Rinkeby Addresses
    // const optContractAddress = '0x1Fc1d9Ab1A89714c7253ce6d19feF86b76637089';
    const compOracleAddress = '0x332b6e69f21acdba5fb3e8dac56ff81878527e06';

    // Mainnet Addresses
    // const optContractAddress = '0xF83A5e34891670637bE3B592d8eDa1ba54e8013f';

    let oracleContract: PloutozOracleInstance;

    let factory: PloutozOptFactoryInstance;

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
    let wethAddress: string;
    let optContractAddress: string;

    let collateralAmt = 15;
    let collateralAmtWei = web3.utils.toWei(String(collateralAmt), 'ether');
    let ethAmtSend = 17;
    let ethAmtSendWei = web3.utils.toWei(String(ethAmtSend), 'ether');
    let liquidityEthAmt = new BigNumber(ethAmtSend).minus(new BigNumber(collateralAmt)).toString();
    let liquidityEthAmtWei = web3.utils.toWei(liquidityEthAmt, 'ether');

    before('获取要测试的期权合约，并抵押发布合约', async () => {
        // await StringComparatorContract.new();
        oracleContract = await PloutozOracleContract.deployed();
        factory = await PloutozOptFactoryContract.deployed();
        wethContract = await WETH9Contract.deployed();
        exchange = await PloutozOptExchangeContract.deployed();

        let supportUSDC = await factory.supportsAsset('USDC');
        if (!supportUSDC) {
            await factory.addAsset('USDC', '0x4DBCdF9B62e891a7cec5A2568C3F4FAF9E8Abe2b');
        }
        let creatRes = await factory.createOptionsContract(
            'oEthc call 400.00 2020/9/10', // name 
            'oEthc call 400.00 2020/9/10', // symbol
            'USDC', // underlying
            'ETH', // strike
            'ETH', // collateral
            '2500', // strikePrice
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
            console.log('strike Price: ' + strikePrice);
            strikePriceDecimals = await optContract.strikePriceDecimals();
            console.log('strike Price Decimals: ' + strikePriceDecimals);
            expiry = await optContract.expiry();
            console.log('expiry: ' + new Date(Number(expiry) * 1000));
            windwosize = await optContract.windowSize();
            console.log('window size: ' + new Date(Number(windwosize) * 1000));
            exchangeAddress = await optContract.exchange();
            console.log('exchange is at: ' + exchangeAddress);

            // put 合约中
            let res = await optContract.createCollateralOption(collateralAmtWei, { value: ethAmtSendWei });

            // let res = await web3.eth.sendTransaction({ from: accounts[0], to: optContract.address, value: web3.utils.toWei('0.005', 'ether'), gas: '1000000', gasPrice: web3.utils.toWei('70', 'gwei') });
            // console.log(res);
        }
    });

    describe('抵押发布期权合约以后，检查数据', async () => {

        it('发布的期权数量应该等于转移到exchange上的期权数量', async () => {
            let tokens = await optContract.balanceOf(exchange.address); // 生成期权合约的数量，这些期权合约将被转给exchange
            let v = new BigNumber(collateralAmt).div(strikePrice).multipliedBy(new BigNumber(10).exponentiatedBy(strikePriceDecimals)).multipliedBy(new BigNumber(10).exponentiatedBy(18)); // 根据抵押数量计算出来的期权数量
            let totalSupply = await optContract.totalSupply();
            expect(tokens.toString()).equal(v.toFixed(0, BigNumber.ROUND_DOWN));
            expect(totalSupply.toString()).equal(v.toFixed(0, BigNumber.ROUND_DOWN));
        });
        it('期权合约上eth的数量应该等于0', async () => {
            let optContractEthBalance = await web3.eth.getBalance(optContractAddress); // 期权合约上的eth的数量，应该为0
            expect(optContractEthBalance).equal('0');
        });
        it('期权合约上weth的数量应该等于抵押的eth的数量', async () => {
            let optContractWETHBalance = await wethContract.balanceOf(optContractAddress); // 期权合约上抵押的weth数量是否正确
            expect(optContractWETHBalance.toString()).equal(collateralAmtWei);
        });
        it('exchange上的eth的数量应该等于剩余的流动性投入的eth数量', async () => {
            let exchangeEthBalance = await web3.eth.getBalance(exchangeAddress);
            expect(new BigNumber(liquidityEthAmtWei).toString()).equal(exchangeEthBalance.toString());
        });
        it('保险库抵押的数量等于抵押数量', async () => {
            let arr = await optContract.getVault(accounts[0]);
            let vCollateralWei = arr[0].toString();
            let vTokenIssueWei = arr[1].toString();
            let vUnderlyingWei = arr[2].toString();
            expect(vCollateralWei).equal(collateralAmtWei);
            let v = new BigNumber(collateralAmt).div(strikePrice).multipliedBy(new BigNumber(10).exponentiatedBy(strikePriceDecimals)).multipliedBy(new BigNumber(10).exponentiatedBy(18)); // 根据抵押数量计算出来的期权数量
            expect(vTokenIssueWei).equal(v.toFixed());
            expect(vUnderlyingWei).equal('0');
        });
    });

});
