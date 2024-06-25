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
	echo "$address"
	echo "$contract_name"
	echo "$constructor_args"

	# Skip if address is null or empty
	if [ "$address" = "null" ] || [ -z "$address" ]; then
		continue
	fi

	# skip if contract_name is null or empty
	if [ "$contract_name" = "null" ] || [ -z "$contract_name" ]; then
		continue
	fi

	# Format constructor arguments
	formatted_args=$(extract_constructor_args "$constructor_args")

	echo "Verifying contract: $contract_name at address $address"

	# Construct and execute the forge verify-contract command
	command="forge verify-contract $address $contract_name \
		--verifier-url $verifierUrl \
		--verifier etherscan \
		--etherscan-api-key $VERIFIER_API_KEY \
		--watch"

	# Add constructor args if present
	if [ -n "$formatted_args" ]; then
		command="$command --constructor-args $formatted_args"
	fi

	trimmedCommand=$(trim_command "$command")

	echo "Executing command: $trimmedCommand"
	eval $trimmedCommand

	echo "Verification process complete for $contract_name"
	echo "----------------------------------------"
done
