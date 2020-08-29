const { expectRevert, time } = require('@openzeppelin/test-helpers');
import { expect, assert } from 'chai';
import { PloutozOptContractContract, PloutozOptContractInstance } from '../build/types/truffle-types';
// Load compiled artifacts
const PloutozOptContract: PloutozOptContractContract = artifacts.require('PloutozOptContract.sol');
const truffleAssert = require('truffle-assertions');
const Web3Utils = require('web3-utils');
import { getUnixTime, addMonths, addSeconds, fromUnixTime } from 'date-fns';

contract('期权合约 Call ETH/USDC', accounts => {
    const creatorAddress = accounts[0];
    const firstOwnerAddress = accounts[1];

    // Rinkeby Addresses
    // const optContractAddress = '0x1Fc1d9Ab1A89714c7253ce6d19feF86b76637089';

    // Mainnet Addresses
    // const optContractAddress = '0xF83A5e34891670637bE3B592d8eDa1ba54e8013f';


    // Deployment Addresses
    const optContractAddress = '0xD42d6d03593fcAB157402539e26b2cc7Ff189dB1';

    let optContract: PloutozOptContractInstance;

    let decimal;
    let symbol;
    let name;
    let underlying;
    let unerlyingExp;
    let strike;
    let collateral;
    let collateralExp;
    let strikePrice;
    let strikePriceDecimals;
    let expiry;
    let windwosize;

    before('获取要测试的期权合约', async () => {
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
        console.log('expiry: ' + new Date(Number(expiry)));
        windwosize = await optContract.windowSize();
        console.log('window size: ' + new Date(Number(windwosize)));
        // let res = await web3.eth.sendTransaction({ from: accounts[0], to: optContract.address, value: web3.utils.toWei('0.005', 'ether'), gas: '1000000', gasPrice: web3.utils.toWei('70', 'gwei') });
        // console.log(res);
    });

    describe('测试一次抵押发布call 合约', () => {
        it('合约应该发布成功', async () => {
            let collateralAmt = web3.utils.toWei('0.1', 'ether');
            let ethAmtSend = web3.utils.toWei('0.2', 'ether');
            // put 合约中
            let res = await optContract.createCollateralOption(collateralAmt, { value: ethAmtSend });
            console.log(res);
        });
    });

});
