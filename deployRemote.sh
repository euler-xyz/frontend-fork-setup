#!/bin/bash
# this script is used to manage the deployment of the contract to a remote network
# Check if REMOTE_RPC_URL is set, if not, prompt the user
# to persist that env variable between sessions
if [ -z "$REMOTE_RPC_URL" ]; then
	echo "Enter Remote RPC URL:"
	read remote_rpc_url
	# break if no rpc url is provided
	if [ -z "$remote_rpc_url" ]; then
		echo "No RPC URL provided, exiting..."
		exit 1
	fi
	export REMOTE_RPC_URL=$remote_rpc_url
else
	# log the rpc url
	echo "Using Remote RPC URL: $REMOTE_RPC_URL"
	rpc_url=$REMOTE_RPC_URL
fi

# Ask for verifier api key
if [ -z "$VERIFIER_API_KEY" ]; then
	echo "Enter Verifier API Key:"
	read verifier_api_key
	# if verifier api key is empty, exit
	if [ -z "$verifier_api_key" ]; then
		echo "No Verifier API Key provided, exiting..."
		exit 1
	fi
	export VERIFIER_API_KEY=$verifier_api_key
else
	# log that the verifier api key is set
	echo "Using Verifier API Key: ********"
	verifier_api_key=$VERIFIER_API_KEY
fi

if [ -z "$MNEMONIC" ]; then
	echo "Enter Mnemonic (Or Press ENTER to use default (test test ... junk)):"
	read mnemonic
	# if mnemonic is empty, use default
	if [ -z "$mnemonic" ]; then
		export MNEMONIC='test test test test test test test test test test test junk'
	else
		export MNEMONIC=$mnemonic
	fi
else
	mnemonic=$MNEMONIC
fi

# confirm you want to deploy
echo "Deploying to $REMOTE_RPC_URL with Verifier API Key: ********"
echo "Do you want to continue? (y/n)"
read confirm
if [ "$confirm" != "y" ]; then
	echo "Exiting..."
	exit 1
fi

# we need to submit transaction with a slow mode to avoid issues
# the script submits and verifies
forge script ./src/DeployLendVaults.sol --rpc-url $REMOTE_RPC_URL --etherscan-api-key $VERIFIER_API_KEY --verifier-url $REMOTE_RPC_URL/verify/etherscan --broadcast --ffi -vvv --slow --mnemonics "$MNEMONIC" --verify --delay 5 --retries 5
