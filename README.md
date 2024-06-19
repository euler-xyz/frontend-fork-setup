## Euler v2 frontend testnet deployer

Deploy a testnet setup for the [EVK](https://github.com/euler-xyz/euler-vault-kit) and [EVC](https://github.com/euler-xyz/ethereum-vault-connector/).

## How to deploy


### Build

```shell
 forge build
```


### Setup tokens

The current setup includes tokens which are deployed on Ethereum mainnet. If you use a forked mainnet, you can use the existing tokens. If you want to deploy to a different network or want to use different tokens, you can edit [forkTokenList.json](data/forkTokenList.json).


### Manual Deployment

To deploy the EVC, mock oracles, mock irms and a vault for each of the tokens in the forkTokenList.json run the following command:

```shell
 MNEMONIC="your mnemonic" forge script ./src/DeployLendVaults.sol --rpc-url "http://your-rpc.com" --broadcast --ffi --slow
```

You will find all of the deployed contract addresses in the [lists/local/](lists/local/) directory.


## Using guided scripts (anvil.sh, deploy.sh)

This documentation provides instructions on how to use the provided Bash scripts for managing Ethereum blockchain deployments with Anvil and a remote RPC network.

### Prerequisites

1. **Node.js and npm**: Ensure you have Node.js and npm installed. You can download and install them from [here](https://nodejs.org/).
2. **Anvil**: Ensure you have Anvil installed for running a local Ethereum testnet.

### Setting Up Your Environment

Create a `.env.local` file in the root directory of your project. This file should contain the necessary environment variables for your scripts. Below is an example of what the `.env.local` file might look like along with explanations for each variable:

#### Example `.env.local` File:

```dotenv
# Environment variables for Anvil script
# URL of the mainnet RPC. Example: https://mainnet.infura.io/v3/YOUR_INFURA_PROJECT_ID
ANVIL_FORK_RPC_URL=

# Environment variables for deployment script
# URL of the remote RPC. Example: https://rinkeby.infura.io/v3/YOUR_INFURA_PROJECT_ID
REMOTE_RPC_URL=
# API key for contract verification. Example: YOUR_ETHERSCAN_API_KEY
VERIFIER_API_KEY=
# Mnemonic for the wallet. Example: "test test test test test test test test test test test junk"
MNEMONIC=
# Name of the script to deploy. Example: MyContract.sol
SCRIPT_NAME=
# Whether to deploy locally (y/n). Example: y
SHOULD_BE_LOCAL_TEST=
```

#### Explanation

- **ANVIL_FORK_RPC_URL**: The URL of the mainnet RPC to fork from. If not set, the script will prompt you to enter it.
- **REMOTE_RPC_URL**: The URL of the remote RPC for contract deployment. If not set, the script will prompt you to enter it.
- **VERIFIER_API_KEY**: The API key for contract verification services like Etherscan. If not set, the script will prompt you to enter it.
- **MNEMONIC**: The mnemonic phrase for the wallet. If not set, the script will prompt you to enter it and provide a default option.
- **SCRIPT_NAME**: The name of the Solidity script to deploy. If not set, the script will prompt you to select one.
- **SHOULD_BE_LOCAL_TEST**: Flag to indicate whether the deployment is local. If not set, the script will prompt you to specify.

If these environment variables are not set in the `.env.local` file, the scripts will prompt you to enter the required information during execution.

### Using the Scripts

#### 1. Anvil Fork RPC URL Setup Script (`anvil.sh`)

This script sets up an Anvil fork using a mainnet RPC URL. It will prompt you to enter the mainnet RPC URL if it is not set in the `.env.local` file.

##### Usage:

1. **Ensure you have the `.env.local` file** with the required variables.
2. **Run the script**:
   ```bash
   . ./anvil.sh
   ```

3. **Follow the prompts**:
   - If `ANVIL_FORK_RPC_URL` is not set, enter the mainnet RPC URL when prompted.
   - If no URL is provided, Anvil will run with default settings.

#### 2. Contract Deployment Management Script (`deploy.sh`)

This script manages the deployment of smart contracts to either a local Anvil testnet or a remote network based on user input.

##### Usage:

1. **Ensure you have the `.env.local` file** with the required variables.
2. **Run the script**:
   ```bash
   . ./deploy.sh
   ```

3. **Follow the prompts**:
   - You will be asked if the deployment is for a local test.
   - If deploying to a remote network, enter the remote RPC URL, verifier API key, and mnemonic when prompted.
   - Select the script you want to deploy if not already specified.
   - Confirm deployment and verification settings.

### Example Workflow

Here is a step-by-step example workflow for using these scripts:

#### Setting Up Anvil

1. **Create `.env.local`**:
   ```dotenv
   ANVIL_FORK_RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_PROJECT_ID
   ```

2. **Run the Anvil setup script**:
   ```bash
   . ./anvil.sh
   ```

3. **Follow the prompts**:
   - If `ANVIL_FORK_RPC_URL` is not set in `.env.local`, you will be prompted to enter it.

#### Deploying Contracts

1. **Create `.env.local`**:
   ```dotenv
   SHOULD_BE_LOCAL_TEST=y
   SCRIPT_NAME=MyContract.sol
   ```

2. **Run the deployment script**:
   ```bash
   . ./deploy.sh
   ```

3. **Follow the prompts**:
   - If `SHOULD_BE_LOCAL_TEST` is not set, specify whether this is a local test.
   - If deploying to a remote network, provide the RPC URL, verifier API key, and mnemonic when prompted.
   - Confirm deployment and verification settings.

By following these instructions, you can easily set up and deploy the contracts using the provided scripts.

## Contract Verification
Some contracts like the GenericFactory can't be picked up by foundry so they won't be verified.
You might see this warning with different contract addresses of course:

```
We haven't found any matching bytecode for the following contracts: [0x3790ae2784142b4c1d519f991227f13c53deea98, 0xa316848ae06fe21389065dbf279b307aa5300c79, 0x951e8fcec37fb7d0df4d8603e404d486811703ca, 0x8278f966ffd89f87edd5fb92e3e1d5aa7ab6c4af, 0xc7e4a78e5a4934df1627206a1dde0bb79a978967, 0x2bf0b698b4738e81469ffa33c341babd63df1863, 0x20a6f1ee55bf00ade2f40db9eeda66221a504989, 0x325cdfc9841fd8c429054c64bcc351b3f55bf89c].

This may occur when resuming a verification, but the underlying source code or compiler version has changed.
```

NOTE:
If the the matching bytecode are more then the amount of contracts you are deploying, you should do `forge clean` and then `forge build` again.

## Intended usage

This setup is intended to be used for testing and development purposes.
It is not intended to be used in a production environment and doing so may result in loss of funds and is in violation of the license agreement defined in the [Euler Vault Kit](https://github.com/euler-xyz/euler-vault-kit?tab=readme-ov-file#license).
