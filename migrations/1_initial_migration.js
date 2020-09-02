const factory = artifacts.require("PloutozOptFactory");
const exchange = artifacts.require("PloutozOptExchange");
const ploutozOracle = artifacts.require("PloutozOracle");
const stringComparator = artifacts.require('StringComparator.sol');
const weth = artifacts.require('WETH9.sol');

const addres0 = "0x0000000000000000000000000000000000000000";
const uniswapFactoryAddress = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f';
const uniswapRouter01Address = '0xf164fC0Ec4E93095b804a4795bBe1e041497b92a';
const uniswapRouter02Address = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';

module.exports = async function (deployer) {
    if (deployer.network.indexOf('skipMigrations') > -1) { // skip migration
        return;
    }
    if (deployer.network_id == 4) { // Rinkeby
        let compoundOracleAddress = "0x332b6e69f21acdba5fb3e8dac56ff81878527e06";
        let stringComparatorLibrary = await deployer.deploy(stringComparator);
        let oracleContract = await deployer.deploy(ploutozOracle, compoundOracleAddress);
        // let wethContract = await deployer.deploy(weth);
        // console.log('WETH contract address: ' + wethContract.address);
        let exchangeContract = await deployer.deploy(exchange, uniswapFactoryAddress, uniswapRouter01Address, uniswapRouter02Address, address0);
        deployer.link(stringComparator, factory);
        let factoryContract = await deployer.deploy(factory, oracleContract.address, exchangeContract.address);
        // let exchangeContract=await deployer.
    } else if (deployer.network_id == 1) { // main net
        let compoundOracleAddress = "0x1D8aEdc9E924730DD3f9641CDb4D1B92B848b4bd";
    } else if (deployer.network_id == 5777) {
        let compoundOracleAddress = "0x1D8aEdc9E924730DD3f9641CDb4D1B92B848b4bd";
        let stringComparatorLibrary = await deployer.deploy(stringComparator);
        let oracleContract = await deployer.deploy(ploutozOracle, compoundOracleAddress);
        let wethContract = await deployer.deploy(weth);
        console.log('WETH contract address: ' + wethContract.address);
        let exchangeContract = await deployer.deploy(exchange, uniswapFactoryAddress, uniswapRouter01Address, uniswapRouter02Address, wethContract.address);
        deployer.link(stringComparator, factory);
        let factoryContract = await deployer.deploy(factory, oracleContract.address, exchangeContract.address);
        // let exchangeContract=await deployer.
    } else if (deployer.network_id == 42) {
        let compoundOracleAddress = "0x6998ed7daf969ea0950e01071aceeee54cccbab5";
        let stringComparatorLibrary = await deployer.deploy(stringComparator);
        let oracleContract = await deployer.deploy(ploutozOracle, compoundOracleAddress);
        // let wethContract = await deployer.deploy(weth);
        // console.log('WETH contract address: ' + wethContract.address);
        let exchangeContract = await deployer.deploy(exchange, uniswapFactoryAddress, uniswapRouter01Address, uniswapRouter02Address, addres0);
        deployer.link(stringComparator, factory);
        let factoryContract = await deployer.deploy(factory, oracleContract.address, exchangeContract.address);
        // let exchangeContract=await deployer.
    } else {

    }

    // deployer.deploy(factory).then(() => {
    // });
    // deployer.deploy(exchange).then(() => {
    // });
};
