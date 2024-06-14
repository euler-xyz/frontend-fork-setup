pragma solidity ^0.8.24;

import "forge-std/StdJson.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {Swapper} from "evk-periphery/Swaps/Swapper.sol";
import {SwapVerifier} from "evk-periphery/Swaps/SwapVerifier.sol";
import "openzeppelin-contracts/utils/Strings.sol";

contract DeploySwapper is Script, Test {
    using stdJson for string;
    using Strings for uint256;

    address constant UNISWAP_V3_ROUTER_V2 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant ONE_INCH_AGGREGATOR_V6 = 0x111111125421cA6dc452d289314280a0f8842A65;
    address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    function run() public {
        execute(true);
    }

    function execute(bool useMnemonic) public {
        address deployer = address(this);
        if (useMnemonic) {
            uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC"), 0);
            deployer = vm.addr(deployerPrivateKey);
            vm.startBroadcast(deployerPrivateKey);
        }
        Swapper swapper = new Swapper(ONE_INCH_AGGREGATOR_V6, UNISWAP_V2_ROUTER, UNISWAP_V3_ROUTER, UNISWAP_V3_ROUTER_V2);
        SwapVerifier swapVerifier = new SwapVerifier();

        string memory outputKey = "data";
        uint256 blockNumber = block.number;
        string memory blockNumberStr = blockNumber.toString();
        vm.serializeAddress(outputKey, "swapper", address(swapper));
        vm.serializeAddress(outputKey, "oneInchAggregator", ONE_INCH_AGGREGATOR_V6);
        vm.serializeAddress(outputKey, "uniswapV2Router", UNISWAP_V2_ROUTER);
        vm.serializeAddress(outputKey, "uniswapV3Router", UNISWAP_V3_ROUTER);
        vm.serializeAddress(outputKey, "uniswapV3RouterV2", UNISWAP_V3_ROUTER_V2);
        string memory result = vm.serializeAddress(outputKey, "swapVerifier", address(swapVerifier));

        string memory location = "./lists/local/";
        vm.writeJson(result, string.concat(location, "swapper-", blockNumberStr, ".json"));
        vm.writeJson(result, string.concat(location, "swapper-latest.json"));
    }
}
