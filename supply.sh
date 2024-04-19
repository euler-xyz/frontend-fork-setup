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

# List all first level json files from /lists/*json
echo "Select a list from the options below:"
select list_option in $(ls ./lists/*.json); do
	export SELECTED_LIST=$(basename "$list_option")
	echo "You selected: $SELECTED_LIST"
	break
done

account=$(cast wallet address --mnemonic "$MNEMONIC")
# Assuming the command outputs the private key in the format you've shown
privateKeyOutput=$(cast wallet derive-private-key "$MNEMONIC")
privateKey=$(echo "$privateKeyOutput" | grep 'Private key:' | awk '{print $3}')

# Now, privateKey variable holds the private key
deployedVaultList=$(pwd)"/lists/$SELECTED_LIST"
deployedVaultListJson=$(cat $deployedVaultList)

approvalValue=1000000
depositValue=100

tokenListPath=$(pwd)"/data/forkTokenList.json"
tokenListJson=$(cat $tokenListPath)

for key in $(echo $deployedVaultListJson | jq -r 'keys[]'); do
	echo "-------------------------------------------------------------------------------------------------------------------------------------------------"
	vaultInfo=$(echo $deployedVaultListJson | jq -r --arg KEY "$key" '.[$KEY]')
	vaultAddress=$(echo $vaultInfo | jq -r '.address')
	vaultAsset=$(echo $vaultInfo | jq -r '.asset')
	# in the tokenListJson find the object in the array that has addressInfo equal to the vaultAsset
	tokenInfo=$(echo $tokenListJson | jq -r --arg VAULT_ASSET "$vaultAsset" '.[] | select(.addressInfo == $VAULT_ASSET)')
	tokenAddress=$(echo $tokenInfo | jq -r '.addressInfo')
	tokenDecimals=$(echo $tokenInfo | jq -r '.decimals')

	echo "Token Address: $tokenAddress"
	echo "Token Decimals: $tokenDecimals"
	echo "Vault Address: $vaultAddress"
	approvalAmount=$(cast to-wei $approvalValue $tokenDecimals)
	depositAmount=$(cast to-wei $depositValue $tokenDecimals)
	echo "Approval Amount: $approvalAmount"

	approvalBefore=$(cast call $vaultAsset "allowance(address,address)(uint256)" $account $vaultAddress --rpc-url $REMOTE_RPC_URL --private-key $privateKey | awk '{print $1}')
	echo "Approval Before $vaultAsset: $approvalBefore"
	if [ "$approvalBefore" != "$approvalAmount" ]; then
		# set approval to zero first to handle stupid tokens
		approveReset=$(cast send --rpc-url $REMOTE_RPC_URL --private-key $privateKey $vaultAsset "approve(address,uint256)(bool)" $vaultAddress 0 | awk '{print $3}')
		approveReset=$(echo $approveReset | awk '{print $1}')
		echo "Approval Reset $vaultAsset: $approveReset"
		approvalSuccess=$(cast send --rpc-url $REMOTE_RPC_URL --private-key $privateKey $vaultAsset "approve(address,uint256)(bool)" $vaultAddress $approvalAmount | awk '{print $3}')
		approvalSuccess=$(echo $approvalSuccess | awk '{print $1}')
		echo "Approval Success: $approvalSuccess"
		approvalAfter=$(cast call $vaultAsset "allowance(address,address)(uint256)" $account $vaultAddress --rpc-url $REMOTE_RPC_URL --private-key $privateKey | awk '{print $1}')
		echo "Approval After $vaultAsset: $approvalAfter"
	fi

	# deposit the amount
	depositSuccess=$(cast send --rpc-url $REMOTE_RPC_URL --private-key $privateKey --gas-limit 1000000 $vaultAddress "deposit(uint256,address)" $depositAmount $account)
	echo "Deposit Success: $depositSuccess"
done
