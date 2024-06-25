import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import "@nomicfoundation/hardhat-foundry";
import * as tdly from "@tenderly/hardhat-tenderly";
import dotenv from "dotenv";

dotenv.config({ path: ".env.local" });
tdly.setup();

const config: HardhatUserConfig = {
	solidity: "0.8.24",
	networks: {
		tenderly: {
			url: process.env.REMOTE_RPC_URL,
			chainId: 41337,
		},
	},
	tenderly: {
		username: "euler-labs" ?? "error",
		project: "euler",

		// Contract visible only in Tenderly.
		// Omitting or setting to `false` makes it visible to the whole world.
		// Alternatively, admin-rpc verification visibility using
		// an environment variable `TENDERLY_PRIVATE_VERIFICATION`.
		privateVerification: true,
	},
};

export default config;
