const { expectRevert, time } = require('@openzeppelin/test-helpers');
import { expect, assert } from 'chai';
import { PloutozOptContractContract, PloutozOptContractInstance, PloutozOptFactoryContract, PloutozOptFactoryInstance, PloutozOracleContract, PloutozOracleInstance, PloutozOptExchangeContract, PloutozOptExchangeInstance } from '../build/types/truffle-types';
// Load compiled artifacts
const PloutozOptContract: PloutozOptContractContract = artifacts.require('PloutozOptContract.sol');
const PloutozOptFactoryContract: PloutozOptFactoryContract = artifacts.require('PloutozOptFactory.sol');
const PloutozOracleContract: PloutozOracleContract = artifacts.require('PloutozOracle.sol');
const PloutozOptExchangeContract: PloutozOptExchangeContract = artifacts.require('PloutozOptExchange.sol');
const truffleAssert = require('truffle-assertions');
const Web3Utils = require('web3-utils');
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

    let decimal;
    let symbol;
    let name;
    let underlying;
    let strike;
    let collateral;
    let strikePrice;
    let strikePriceDecimals;
    let expiry;
    let windwosize;
    let exchangeAddress;

    before('获取要测试的期权合约', async () => {
        // await StringComparatorContract.new();
        oracleContract = await PloutozOracleContract.deployed();
        factory = await PloutozOptFactoryContract.deployed();
        // exchange = await PloutozOptExchangeContract.deployed();

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
            '1598344440', // windowsize
            '0xAF720c51e5100207852900a34C4DdFf8E056E0c7' // exchange address
        );
        let optContractAddress;
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
            strikePrice = await optContract.strikePrice();
            console.log('strike Price: ' + strikePrice);
            strikePriceDecimals = await optContract.strikePriceDecimals();
            console.log('strike Price Decimals: ' + strikePriceDecimals);
            expiry = await optContract.expiry();
            console.log('expiry: ' + new Date(Number(expiry) * 1000));
            windwosize = await optContract.windowSize();
            console.log('window size: ' + new Date(Number(windwosize) * 1000));
            exchangeAddress = await optContract.exchange();
            console.log('exchange is at: ' + exchangeAddress);
            // let res = await web3.eth.sendTransaction({ from: accounts[0], to: optContract.address, value: web3.utils.toWei('0.005', 'ether'), gas: '1000000', gasPrice: web3.utils.toWei('70', 'gwei') });
            // console.log(res);
        }
    });

    describe('测试一次抵押发布call 合约', () => {
        it('合约应该发布成功', async () => {
            let collateralAmt = web3.utils.toWei('1', 'ether');
            let ethAmtSend = web3.utils.toWei('2', 'ether');
            // put 合约中
            let res = await optContract.createCollateralOption(collateralAmt, { value: ethAmtSend });
            console.log(res.logs);
        });
    });

});
