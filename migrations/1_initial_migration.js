// const factory = artifacts.require("OptionsFactory");
// const exchange = artifacts.require("OptionsExchange");
// const ploutozOracle = artifacts.require("PloutozOracle");

module.exports = async function (deployer) {
    if (deployer.network.indexOf('skipMigrations') > -1) { // skip migration
        return;
    }
    if (deployer.network_id == 4) { // Rinkeby
        let compoundOracleAddress = "0x332b6e69f21acdba5fb3e8dac56ff81878527e06";
        // let oContract = await deployer.deploy(ploutozOracle, compoundOracleAddress);
        // console.log(oContract.address);
    } else if (deployer.network_id == 1) { // main net
        let compoundOracleAddress = "0x1D8aEdc9E924730DD3f9641CDb4D1B92B848b4bd";
    } else {

    }

    // deployer.deploy(factory).then(() => {
    // });
    // deployer.deploy(exchange).then(() => {
    // });
};
