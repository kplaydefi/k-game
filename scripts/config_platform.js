const {green}  = require("chalk");
const {table}  = require("table");
const hre      = require("hardhat");
const networks = require("../resources/networks.json");
const {
          deployments,
          getNamedAccounts,
          network,
      }        = hre;

module.exports = (async () => {
    const {deployer} = await getNamedAccounts();
    const resource   = networks[network.name];
    const PlatformGame       = await deployments.get("PlatformGame");

    const txs               = [["Method", "Value", "Transaction"]];
    const sendGameStorageTx = async (method, value) => {
        console.log(`Sending ${method} transaction .....`);
        const tx = await deployments.execute(
            "GameStorage",
            {from: deployer},
            method,
            value,
        );
        txs.push([method, value, `"${resource.explorer}/tx/${tx.transactionHash}"`]);
    };

    const gameStorageTxs = new Map();
    gameStorageTxs.set("setAdmin", PlatformGame.address);
    gameStorageTxs.set("setRelationship", resource.RELATIONSHIP_CONTRACT);
    gameStorageTxs.set("setPlatformFeeDst", resource.PLATFORM_FEE_RECEIVING_ADDRESS);

    for (let [method, value] of gameStorageTxs.entries()) {
        await sendGameStorageTx(method, value);
    }
    console.log(green(table(txs)));
})();

