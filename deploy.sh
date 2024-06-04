#!/bin/bash

source .env.local

# ask for SHOULD_BE_LOCAL_TEST loaded as env liket the ones below (y/n)
if [ -z "$SHOULD_BE_LOCAL_TEST" ]; then
	echo "Should this be local anvil deploy (testing)? (y/n):"
	read should_be_local_test
	export SHOULD_BE_LOCAL_TEST=$should_be_local_test
	# check if there is anvil running on port 8545
	if [ "$SHOULD_BE_LOCAL_TEST" = "y" ]; then
		echo "Checking if there is anvil running on port 8545..."
		if [ -z "$(lsof -i :8545)" ]; then
			echo "No anvil found, exiting... Run .anvil.sh before deploying locally"
			exit 1
		fi
	fi
fi

export VERIFIER_API_KEY="" #placeholder for the foundry.toml

# if not SHOULD BE LOCAL TEST, then ask for REMOTE_RPC_URL
if [ "$SHOULD_BE_LOCAL_TEST" != "y" ]; then
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
	if [ -z "$VERIFIER_API_KEY" -o "$VERIFIER_API_KEY" = "" ]; then
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
else
	echo "Using Local RPC URL: http://127.0.0.1:8545"
	export REMOTE_RPC_URL=http://127.0.0.1:8545
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

# ask if we need to deal tokens
echo "Do you want to deal tokens? (y/n):"
read deal_tokens
if [ "$deal_tokens" = "y" ]; then
	MNEMONIC=$MNEMONIC REMOTE_RPC_URL=$REMOTE_RPC_URL ./deal.sh
fi

if [ -z "$SCRIPT_NAME" ]; then
	echo "Select a script to deploy from the list below:"
	select script_name in $(ls ./src/*.sol); do
		export SCRIPT_NAME=$(basename "$script_name")
		echo "You selected to deploy: $SCRIPT_NAME"
		break
	done
fi

# if should be local test ?
if [ "$SHOULD_BE_LOCAL_TEST" = "y" ]; then
	echo "Deploying $SCRIPT_NAME locally on: http://127.0.0.1:8545"
	# without --legacy we can sometimes get
	# Error:
	# Failed to get EIP-1559 fees
	MNEMONIC=$MNEMONIC forge script ./src/$SCRIPT_NAME --rpc-url http://127.0.0.1:8545 --legacy --ffi -vvvv --broadcast --mnemonics "$MNEMONIC" --slow
else

	# ask if we should verify contracts
	echo "Do you want to verify contracts? (y/n):"
	read verify_contracts

	# confirm you want to deploy
	echo "Deploying $SCRIPT_NAME to $REMOTE_RPC_URL with Verifier API Key: ********"
	echo "Do you want to continue? (y/n)"
	read confirm
	if [ "$confirm" != "y" ]; then
		echo "Exiting..."
		exit 1
	fi
	# we need to submit transaction with a slow mode to avoid issues
	# the script submits and verifies
	if [ "$verify_contracts" = "y" ]; then
		MNEMONIC=$MNEMONIC forge script ./src/$SCRIPT_NAME --rpc-url $REMOTE_RPC_URL --etherscan-api-key $VERIFIER_API_KEY --verifier-url $REMOTE_RPC_URL/verify/etherscan --broadcast --ffi -vvv --slow --mnemonics "$MNEMONIC" --verify --delay 5 --retries 5
	else
		MNEMONIC=$MNEMONIC forge script ./src/$SCRIPT_NAME --rpc-url $REMOTE_RPC_URL --broadcast --ffi -vvv --slow --mnemonics "$MNEMONIC"
	fi
fi
