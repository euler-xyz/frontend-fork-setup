#!/bin/bash
source .env.local

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

# run evm_increaseTime
# ask for how many days to increase the time by
echo "Enter the number of days to increase the time by:"
read days

# calculate how much is x days in seconds
daysInSeconds=$(($days * 24 * 60 * 60))
echo "Increasing time by $daysInSeconds seconds"

# convert the daysInSeconds into hex
daysInSecondsHex=$(printf '0x%x' $daysInSeconds)
echo "Increasing time by $daysInSecondsHex hex"


cast rpc --rpc-url $REMOTE_RPC_URL evm_increaseTime $daysInSecondsHex
