const factory = artifacts.require("OptionFactory");
const exchange = artifacts.require("OptionExchange");

module.exports = function (deployer) {
    deployer.deploy(factory).then(() => {
    });
    deployer.deploy(exchange).then(() => {
    });
};
