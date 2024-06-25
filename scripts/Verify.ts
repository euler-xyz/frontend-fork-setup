import { tenderly } from "hardhat";
import fs from "node:fs";
import path from "node:path";

async function main() {
	// Read the JSON file
	const jsonPath = path.join(
		__dirname,
		"../broadcast/DeployLendVaults.sol/41337/run-latest.json",
	);
	const jsonData = JSON.parse(fs.readFileSync(jsonPath, "utf-8"));

	// Array to store verification promises
	const verificationPromises = [];

	for (const tx of jsonData.transactions) {
		if (tx.contractAddress && tx.contractName) {
			console.log(`Verifying ${tx.contractName} at ${tx.contractAddress}`);

			const verificationPromise = tenderly.verify({
				name: tx.contractName,
				address: tx.contractAddress,
			});

			verificationPromises.push(verificationPromise);
		}
	}

	// Wait for all verifications to complete
	await Promise.all(verificationPromises);

	console.log("All contracts verified!");
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
