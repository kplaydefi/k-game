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
    npm run temp
```

Polygon Test Network

| Contract | Address |
| --- | --- |
| GameStorage | [0x9Ef7B986B8FcedA5A63C02b0E66CAe94466E28B8](https://mumbai.polygonscan.com/address/0x9Ef7B986B8FcedA5A63C02b0E66CAe94466E28B8) |
| Game | [0xeC2A8EFD3AD86be7F3036602Fd174BAD7d1Cb2Af](https://mumbai.polygonscan.com/address/0xeC2A8EFD3AD86be7F3036602Fd174BAD7d1Cb2Af) |