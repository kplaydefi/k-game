const hre      = require("hardhat");
const networks = require("../resources/networks.json");
const {green}  = require("chalk");
const {table}  = require("table");
const {
          deployments,
          getNamedAccounts,
          network,
      }        = hre;

module.exports = async () => {
    const {deploy}   = deployments;
    const {deployer} = await getNamedAccounts();
    const resource   = networks[network.name];
    const contracts  = [["Contract", "Address", "Transaction"]];
    if (!deployer) {
        throw new Error(`Deployer configuration not found.`);
    }
    if (!resource) {
        throw new Error(`Failed to read "${network.name}" network configuration, please check resource config.`);
    }
    console.log(`Start deploying contract at "${network.name}" network. deployer=${deployer}`);

    const gameStorage = await deploy("GameStorage", {
        from: deployer,
        args: [resource.TOKEN_CONTRACT],
    });
    contracts.push(["GameStorage", `"${resource.explorer}/address/${gameStorage.address}"`, `"${resource.explorer}/tx/${gameStorage.transactionHash}"`]);

    const proxyGame = await deploy("ProxyGame", {
        from: deployer,
        args: [gameStorage.address],
    });
    contracts.push(["ProxyGame", `"${resource.explorer}/address/${proxyGame.address}"`, `"${resource.explorer}/tx/${proxyGame.transactionHash}"`]);

    // const platformGame = await deploy("PlatformGame", {
    //     from: deployer,
    //     args: [gameStorage.address],
    // });
    // contracts.push(["PlatformGame", `"${resource.explorer}/address/${platformGame.address}"`, `"${resource.explorer}/tx/${platformGame.transactionHash}"`]);

    console.log(green(table(contracts)));
};

module.exports.tags = ["GameStorage"];