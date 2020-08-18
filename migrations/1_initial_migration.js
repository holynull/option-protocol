const Auth = artifacts.require("Auth");
const Box = artifacts.require("Box");

module.exports = function (deployer) {
    deployer.deploy(Auth).then(() => {
        deployer.deploy(Box, Auth.address).then();
    });
};
