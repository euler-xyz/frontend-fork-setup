#!/bin/bash

# this script is used to deal tokens to the specified account
# check if MNEMONIC is set, if not, prompt the user
if [ -z "$MNEMONIC" ]; then
	echo "Enter Mnemonic:"
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

rpc_url=$REMOTE_RPC_URL

# check if remote rpc has tenderly inside
# if so run tenderlyDeal and skip the rest
if [[ $rpc_url == *"tenderly"* ]]; then
	echo "Running tenderlyDeal..."
	./tenderlyDeal.sh
	exit 0
fi


account=$(cast wallet address --mnemonic "$MNEMONIC")
dealValue=1000000

echo "Trying to deal the tokens to $account..."

# Load the token list from the JSON file
tokenListPath=$(pwd)"/data/forkTokenList.json"
tokenListJson=$(cat $tokenListPath)
dummyValue=12345

# Loop through the JSON array of tokens
for row in $(echo "${tokenListJson}" | jq -r '.[] | @base64'); do
	_jq() {
		echo ${row} | base64 --decode | jq -r ${1}
	}

	# Get the token address, decimals and symbol
	asset=$(_jq '.addressInfo')
	decimals=$(_jq '.decimals')
	symbol=$(_jq '.symbol')

	dealValueCalc=$(echo "obase=16; $dealValue * 10^$decimals" | bc)
	dealValueHex="0x$(printf '%064s' $dealValueCalc | tr ' ' '0')"
	successfullyDealt=false

	for i in {0..9}; do
		# calculate the storage index
		slotIndex=$(cast index address $account $i)

		# get the original value of the storage slot at the index
		slotOriginalValue=$(cast rpc --rpc-url $rpc_url eth_getStorageAt $asset $slotIndex "latest")

		# set the storage slot to a dummy value
		cast rpc --rpc-url $rpc_url anvil_setStorageAt $asset $slotIndex $(printf '0x%.64x' $dummyValue) > /dev/null

		# get the balance of the account to check if the storage slot was set to the dummy value
		balance=$(cast call $asset "balanceOf(address)(uint256)" $account | awk '{print $1}')

		# check if the storage slot has been set to the expected dummy value
    	if [ $balance -eq $dummyValue ]; then
			# if the storage slot was found, set the storage slot to the deal value
			cast rpc --rpc-url $rpc_url anvil_setStorageAt $asset $slotIndex $dealValueHex > /dev/null
			successfullyDealt=true

			echo "Successfully dealt $symbol"
			break
    	else
	   		# if the storage slot was not found, set the storage slot back to the original value
        	cast rpc --rpc-url $rpc_url anvil_setStorageAt $asset $slotIndex $slotOriginalValue > /dev/null
    	fi
	done
	
	if [ $successfullyDealt = false ]; then
		echo "Failed to deal $symbol!"
	fi
done

echo Done
