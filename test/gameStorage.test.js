const {expect} = require("./chai-setup");
const networks = require("../resources/networks.json");
const {
          network,
          ethers,
      }        = require("hardhat");

describe("GameStorage", () => {
    it("verify gameStorage config", async function () {
        const resource  = networks[network.name];
        const Game      = await ethers.getContract("Game");
        const GameStore = await ethers.getContract("GameStorage");

        // Verify token contract address
        await expect(await GameStore.tokenContract()).to.equal(resource.TOKEN_CONTRACT);

        // Verify admin address equal game contract
        await expect(await GameStore.admin()).to.equal(Game.address);

        // Verify proxy address
        await expect(await GameStore.proxy()).to.equal(resource.PROXY_ADDRESS);

        // Verify proxy fee contract address
        await expect(await GameStore.proxyFee()).to.equal(resource.PROXY_FEE_CONTRACT);

        // Verify relationship contract address
        await expect(await GameStore.relationship()).to.equal(resource.RELATIONSHIP_CONTRACT);

        // Verify proxy fee receiving address
        await expect(await GameStore.proxyFeeDst()).to.equal(resource.PROXY_FEE_RECEIVING_ADDRESS);

        // Verify platform fee receiving address
        await expect(await GameStore.platformFeeDst()).to.equal(resource.PLATFORM_FEE_RECEIVING_ADDRESS);

        // Verify platform fee rate
        await expect(await GameStore.proxyFeeRate()).to.equal(resource.PROXY_FEE_RARE);
    });
});