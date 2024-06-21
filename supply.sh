#!/bin/bash
source .env.local

# Check if MNEMONIC is set, if not, prompt the user
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

# Check if REMOTE_RPC_URL is set, if not, prompt the user
if [ -z "$REMOTE_RPC_URL" ]; then
	echo "Enter Remote RPC URL:"
	read remote_rpc_url
	# if remote rpc url is empty, exit
	if [ -z "$remote_rpc_url" ]; then
		echo "No Remote RPC URL provided, exiting..."
		exit 1
	fi
	export REMOTE_RPC_URL=$remote_rpc_url
else
	echo "Using Remote RPC URL: $REMOTE_RPC_URL"
fi

echo "Enter Perspective Address:"
read perspective_address
# verify that this is an ethereum address
if [[ ! $perspective_address =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    echo "Invalid Ethereum address. Exiting..."
    exit 1
fi



account=$(cast wallet address --mnemonic "$MNEMONIC")
# Assuming the command outputs the private key in the format you've shown
privateKeyOutput=$(cast wallet derive-private-key "$MNEMONIC")
privateKey=$(echo "$privateKeyOutput" | grep 'Private key:' | awk '{print $3}')
# Now, privateKey variable holds the private key

approvalValue=1000000
depositValue=100

verifiedArrayJson=$(cast call $perspective_address "verifiedArray()(address[])" --rpc-url $REMOTE_RPC_URL)
echo "Verified Array: $verifiedArray"

verifiedArray=$(echo $verifiedArrayJson | tr -d '[],')
for vault_address in $verifiedArray; do
	asset_address=$(cast call $vault_address "asset()(address)" --rpc-url $REMOTE_RPC_URL)
	asset_decimals=$(cast call $asset_address "decimals()(uint8)" --rpc-url $REMOTE_RPC_URL)

	echo "Asset Address: $asset_address"
	echo "Asset Decimals: $asset_decimals"

	approvalAmount=$(cast to-wei $approvalValue $asset_decimals)
	depositAmount=$(cast to-wei $depositValue $asset_decimals)

	echo "Approval Amount: $approvalAmount"

	approvalBefore=$(cast call $asset_address "allowance(address,address)(uint256)" $account $vault_address --rpc-url $REMOTE_RPC_URL --private-key $privateKey | awk '{print $1}')
	echo "Approval Before $asset_address: $approvalBefore"

	if [ "$approvalBefore" != "$approvalAmount" ]; then
		# set approval to zero first to handle potential issues with some tokens
		approveReset=$(cast send --rpc-url $REMOTE_RPC_URL --private-key $privateKey $asset_address "approve(address,uint256)(bool)" $vault_address 0 | awk '{print $3}')
		approveReset=$(echo $approveReset | awk '{print $1}')
		echo "Approval Reset $asset_address: $approveReset"

		approvalSuccess=$(cast send --rpc-url $REMOTE_RPC_URL --private-key $privateKey $asset_address "approve(address,uint256)(bool)" $vault_address $approvalAmount | awk '{print $3}')
		approvalSuccess=$(echo $approvalSuccess | awk '{print $1}')
		echo "Approval Success: $approvalSuccess"

		approvalAfter=$(cast call $asset_address "allowance(address,address)(uint256)" $account $vault_address --rpc-url $REMOTE_RPC_URL --private-key $privateKey | awk '{print $1}')
		echo "Approval After $asset_address: $approvalAfter"
	fi

	# deposit the amount
	depositSuccess=$(cast send --rpc-url $REMOTE_RPC_URL --private-key $privateKey --gas-limit 1000000 $vault_address "deposit(uint256,address)" $depositAmount $account)
	echo "Deposit Success: $depositSuccess"
done
