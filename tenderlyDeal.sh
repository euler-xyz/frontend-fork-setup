#!/bin/bash
source .env.local
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

rpc_url=$REMOTE_RPC_URL

# select mnemonic index from 0 to 10. ask the user
echo "Enter account index (0-256):"
read accountIndex
# if accountIndex is not a number, exit
if ! [[ $accountIndex =~ ^[0-9]+$ ]]; then
	echo "Invalid account index"
	exit 1
fi

# if accountIndex is greater than 256, exit
if [ $accountIndex -gt 256 ]; then
	echo "Account index is greater than 256"
	exit 1
fi

account=$(cast wallet address --mnemonic "$MNEMONIC" --mnemonic-index $accountIndex)
dealValue=1000000

echo "Trying to deal the tokens to $account..."

# Load the token list from the JSON file
tokenListPath=$(pwd)"/data/forkTokenList.json"
tokenListJson=$(cat $tokenListPath)

# Loop through the JSON array of tokens
for row in $(echo "${tokenListJson}" | jq -r '.[] | @base64'); do
	echo "--------------------------------------------------------------------------------"
	_jq() {
		echo ${row} | base64 --decode | jq -r ${1}
	}

	# Get the token address, decimals and symbol
	asset=$(_jq '.addressInfo')
	decimals=$(_jq '.decimals')
	symbol=$(_jq '.symbol')

	dealValueCalc=$(echo "obase=16; $dealValue * 10^$decimals" | bc)
	dealValueHex="0x$(printf $dealValueCalc)"
	echo "Deal value in hex: $dealValueHex"
	# successfullyDealt=false

	# https://docs.tenderly.co/devnets/advanced/custom-rpc-methods#tenderly_seterc20balance
	# {
	# 	"jsonrpc": "2.0",
	# 	"method": "tenderly_setErc20Balance",
	# 	"params": [
	# 	"0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
	# 	"0x40BdB4497614bAe1A67061EE20AAdE3c2067AC9e",
	# 	"0xDE0B6B3A7640000"
	# 	],
	# 	"id": 3640
	# }

	# Construct the JSON payload
	jsonPayload=$(jq -n \
		--arg account "$account" \
		--arg asset "$asset" \
		--arg dealValueHex "$dealValueHex" \
		'{
                    "jsonrpc": "2.0",
                    "method": "tenderly_setErc20Balance",
                    "params": [
                      $asset,
                      $account,
                      $dealValueHex
                    ],
                    "id": 1
                  }')

	echo "JSON payload for $symbol: $jsonPayload"

	response=$(curl -s -X POST $rpc_url \
		-H "Content-Type: application/json" \
		-d "$jsonPayload")

	# example response
	# {
	# 	"id": 3640,
	# 	"jsonrpc": "2.0",
	# 	"result": "0x8a84686634729c57532b9ffa4e632e241b2de5c880c771c5c214d5e7ec465b1c"
	# }

	echo "Response for token $symbol: $response"
done

echo Done
