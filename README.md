# k-game
Game smart contract

## Compile contract
```shell
    npm run compile
```

## Deploy
```shell
    npm run deploy:network [network]
    # The private key of the account to deploy the contract needs to be specified in the environment variable 'DEPLOYER_PRIVATE_KEY'
    # e.g export DEPLOYER_PRIVATE_KEY=your private key
```

## Init storage contract config
```shell
    # GameStorage config transactions
    npm run config:network [network]
```


## Test
```shell
    npm run test
```

Polygon Test Network

| Contract | Address |
| --- | --- |
| GameStorage | [0x88EEFb0D35F8b0e76D3B01F4a76c681c8F7F4EF0](https://mumbai.polygonscan.com/address/0x88EEFb0D35F8b0e76D3B01F4a76c681c8F7F4EF0) |
| ProxyGame | [0x60612F8f600e1dA23917BB1AA674bb9c6fd1306a](https://mumbai.polygonscan.com/address/0x60612F8f600e1dA23917BB1AA674bb9c6fd1306a) |
| PlatformGame | [0x7B7e79ae453d71F541b0f1BdE7e8B9f6dd74A132](https://mumbai.polygonscan.com/address/0x7B7e79ae453d71F541b0f1BdE7e8B9f6dd74A132) |