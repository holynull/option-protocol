import { expect, assert } from 'chai';
import { PloutozOptFactoryContract, PloutozOptFactoryInstance, PloutozOptExchangeInstance } from '../build/types/truffle-types';
// Load compiled artifacts
const OptionsExchange = artifacts.require('PloutozOptExchange.sol');
const truffleAssert = require('truffle-assertions');
const Web3Utils = require('web3-utils');

contract('Ploutoz Option Contract Factory', accounts => {
    const creatorAddress = accounts[0];
    const firstOwnerAddress = accounts[1];

    // Rinkeby Addresses
    const exchangeAddress = '0x3f7B10985Cb9F17BA2ecD5BF49A1Bf0292898297';
    const oracleAddress = '0x3988384227b347a824f4F42f9aE54c57436AC09A';
    const uniswapFactoryAddr = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f';
    const uniswapRouter01Addr = '0xf164fC0Ec4E93095b804a4795bBe1e041497b92a';
    const uniswapRouter02Addr = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';

    // Mainnet Addresses
    // const exchangeAddress = '0xBbe383201027b5406bf7D0C9aa97103f0a1dEc68';
    // const oracleAddress = '0x27F545300F7b93c1c0184979762622Db043b0805';
    // const uniswapFactoryAddr = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
    // const uniswapRouter01Addr = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
    // const uniswapRouter02Addr = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';

    let exchange:PloutozOptExchangeInstance;
    before('set up exchange contracts', async () => {
        exchange = await OptionsExchange.at(exchangeAddress);
    });
    describe('测试交易', () => {
        
    });
    
});
