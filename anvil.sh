#!/bin/bash
source .env.local

# Check if ANVIL_FORK_RPC_URL is set, if not, prompt the user
# to persist that env variable between sessions
# run the script with . ./location/to/this/script.sh
if [ -z "$ANVIL_FORK_RPC_URL" ]; then
	echo "Enter the mainnet RPC URL:"
	read rpc_url
	export ANVIL_FORK_RPC_URL=$rpc_url
else
	rpc_url=$ANVIL_FORK_RPC_URL
fi

# if rpc is empty, use default
if [ -z "$rpc_url" ]; then
	anvil
else
	anvil --fork-url $rpc_url --chain-id 41337 --gas-limit 1000000000 --block-base-fee-per-gas 1 --gas-price 1 --memory-limit 18446744073709551615 --no-storage-caching --compute-units-per-second 600 --no-rate-limit --config-out ./anvil.json
fi
