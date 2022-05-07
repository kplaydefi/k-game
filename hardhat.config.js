require("hardhat-deploy");
require("@nomiclabs/hardhat-ethers");


module.exports = {
    defaultNetwork: "mumbai",
    networks:       {
        //polygon mumbai Testnet
        mumbai: {
            url:      "https://polygon-mumbai.g.alchemy.com/v2/us5J6Fe3MuDLSoqxgp_vrv85e6BUV3mc",
            accounts: [process.env["DEPLOYER_PRIVATE_KEY"]],
            saveDeployments: true,
        },
    },
    solidity:       {
        version:  "0.8.7",
        settings: {
            optimizer: {
                enabled: true,
                runs:    200,
            },
        },
    },
    paths:          {
        deployments: 'deployments',
        sources:   "./contracts",
        tests:     "./test",
        cache:     "./cache",
        artifacts: "./artifacts"
    },
    mocha:          {
        timeout: 40000,
    },
    namedAccounts:  {
        deployer: 0,
    },
};