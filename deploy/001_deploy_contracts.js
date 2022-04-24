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

    const game = await deploy("Game", {
        from: deployer,
        args: [gameStorage.address],
    });
    contracts.push(["Game", `"${resource.explorer}/address/${game.address}"`, `"${resource.explorer}/tx/${game.transactionHash}"`]);
    console.log(green(table(contracts)));
};

module.exports.tags = ["GameStorage"];