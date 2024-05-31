## Euler v2 frontend testnet deployer

Deploy a testnet setup for the [EVK](https://github.com/euler-xyz/euler-vault-kit) and [EVC](https://github.com/euler-xyz/ethereum-vault-connector/).

## How to deploy


### Build

```shell
 forge build
```


### Setup tokens

The current setup includes tokens which are deployed on Ethereum mainnet. If you use a forked mainnet, you can use the existing tokens. If you want to deploy to a different network or want to use different tokens, you can edit [forkTokenList.json](data/forkTokenList.json).


### Deploy

To deploy the EVC, mock oracles, mock irms and a vault for each of the tokens in the forkTokenList.json run the following command:

```shell
 MNEMONIC="your mnemonic" forge script ./src/DeployLendVaults.sol --rpc-url "http://your-rpc.com" --broadcast --ffi --slow
```

You will find all of the deployed contract addresses in the [lists/local/](lists/local/) directory.


## Intended usage

This setup is intended to be used for testing and development purposes.
It is not intended to be used in a production environment and doing so may result in loss of funds and is in violation of the license agreement defined in the [Euler Vault Kit](https://github.com/euler-xyz/euler-vault-kit?tab=readme-ov-file#license).