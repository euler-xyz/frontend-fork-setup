#!/bin/bash
source .env.local

if [ -z "$VERIFIER_API_KEY" ]; then
	read -p "Enter your VERIFIER_API_KEY: " VERIFIER_API_KEY
	export VERIFIER_API_KEY
fi
export ETHERSCAN_API_KEY=$VERIFIER_API_KEY

if [ -z "$REMOTE_RPC_URL" ]; then
	read -p "Enter your REMOTE_RPC_URL: " REMOTE_RPC_URL
	export REMOTE_RPC_URL
fi

verifierUrl="${REMOTE_RPC_URL}/verify/etherscan"
chainId=41337

# Function to extract and format constructor arguments
extract_constructor_args() {
	local args="$1"
	# Remove the '0x' prefix if present
	args="${args#0x}"
	echo "$args"
}

# Function to list JSON files and let user select one
select_json_file() {
	local base_dir="broadcast"

	# List all deployment script directories
	echo "Select a deployment script:"
	select script_dir in "$base_dir"/*; do
		if [ -n "$script_dir" ]; then
			break
		else
			echo "Invalid selection. Please try again."
		fi
	done

	# List all chain ID directories within the selected script directory
	echo "Select a chain ID:"
	select chain_dir in "$script_dir"/*; do
		if [ -n "$chain_dir" ]; then
			break
		else
			echo "Invalid selection. Please try again."
		fi
	done

	# List all JSON files in the selected chain directory
	echo "Select a JSON file:"
	select json_file in "$chain_dir"/*.json; do
		if [ -n "$json_file" ]; then
			echo "Selected file: $json_file"
			return 0
		else
			echo "Invalid selection. Please try again."
		fi
	done
}

# Function to ABI encode constructor arguments
abi_encode_args() {
	local contract_name="$1"
	local args="$2"

	# Get the full ABI
	local abi=$(forge inspect "$contract_name" abi)

	# Extract the constructor from the ABI
	local constructor=$(echo "$abi" | jq 'map(select(.type == "constructor"))[0]')

	if [ -z "$constructor" ] || [ "$constructor" = "null" ]; then
		echo ""
	else
		# Extract the input types from the constructor
		local input_types=$(echo "$constructor" | jq -r '.inputs | map(.type) | join(",")')

		argsSeparatedBySpace=$(echo "$args" | tr ',' ' ')
		encoded_args=$(cast abi-encode "constructor($input_types)" $argsSeparatedBySpace)

		echo "${encoded_args}" # Remove '0x' prefix
	fi
}

trim_command() {
	echo "$1" | sed -E 's/[[:space:]]+/ /g'
}

# Call function to select JSON file
select_json_file

# Read the JSON data from the selected file
json_data=$(cat "$json_file")
# Loop through each transaction in the JSON data
echo "$json_data" | jq -c '.transactions[]' | while read -r transaction; do
	# Extract relevant information
	address=$(echo "$transaction" | jq -r '.contractAddress')
	contract_name=$(echo "$transaction" | jq -r '.contractName')
	constructor_args=$(echo "$transaction" | jq -r '.arguments | join(",")')
	transaction_type=$(echo "$transaction" | jq -r '.transactionType')

	# Skip if address is null or empty
	if [ "$address" = "null" ] || [ -z "$address" ]; then
		continue
	fi

	# skip if contract_name is null or empty
	if [ "$contract_name" = "null" ] || [ -z "$contract_name" ]; then
		continue
	fi

	# Check if transaction type is CREATE
	if [ "$transaction_type" != "CREATE" ]; then
		echo "Skipping non-CREATE transaction for $contract_name"
		continue
	fi

	echo "$address"
	echo "$contract_name"
	echo "$constructor_args"

	encoded_args=$(abi_encode_args "$contract_name" "$constructor_args")
	echo "encoded_args: $encoded_args"

	echo "Verifying contract: $contract_name at address $address"

	# Construct and execute the forge verify-contract command
	command="forge verify-contract $address $contract_name \
		--verifier-url $verifierUrl \
		--etherscan-api-key $VERIFIER_API_KEY \
		--chain 41337 \
		--retries 10 \
		--delay 10 \
		--watch"

	# Add constructor args if present
	if [ -n "$encoded_args" ]; then
		command="$command --constructor-args $encoded_args"
	fi

	trimmedCommand=$(trim_command "$command")

	echo "Executing command: $trimmedCommand"
	eval $trimmedCommand

	echo "Verification process complete for $contract_name"
	echo "----------------------------------------"
done
