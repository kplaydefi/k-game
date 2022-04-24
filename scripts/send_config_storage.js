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
    const Game       = await deployments.get("Game");

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
    gameStorageTxs.set("setRelationship", resource.RELATIONSHIP_CONTRACT);
    gameStorageTxs.set("setAdmin", Game.address);
    gameStorageTxs.set("setProxy", resource.PROXY_ADDRESS);
    gameStorageTxs.set("setProxyFee", resource.PROXY_FEE_CONTRACT);
    gameStorageTxs.set("setProxyFeeRate", resource.PROXY_FEE_RARE);
    gameStorageTxs.set("setProxyFeeDst", resource.PROXY_FEE_RECEIVING_ADDRESS);
    gameStorageTxs.set("setPlatformFeeDst", resource.PLATFORM_FEE_RECEIVING_ADDRESS);

    for (let [method, value] of gameStorageTxs.entries()) {
        await sendGameStorageTx(method, value);
    }
    console.log(green(table(txs)));
})();

