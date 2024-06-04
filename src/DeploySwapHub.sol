pragma solidity ^0.8.24;

import "forge-std/StdJson.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {SwapHub} from "swaps/SwapHub.sol";
import {SwapHandlerUniAutoRouter} from "swaps/swapHandlers/SwapHandlerUniAutoRouter.sol";
import {SwapHandler1Inch} from "swaps/swapHandlers/SwapHandler1Inch.sol";
import {SwapHandlerUniswapV3} from "swaps/swapHandlers/SwapHandlerUniswapV3.sol";
import "openzeppelin-contracts/utils/Strings.sol";

contract DeploySwapHub is Script, Test {
    using stdJson for string;
    using Strings for uint256;

    address constant UNISWAP_V3_ROUTER_0_2 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

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
        SwapHub swapHub = new SwapHub();
        //TODO: add more swap handlers
        // SwapHandlerUniAutoRouter swapHandlerUniAutoRouter = new SwapHandlerUniAutoRouter();
        // SwapHandler1Inch swapHandler1Inch = new SwapHandler1Inch();
        SwapHandlerUniswapV3 swapHandlerUniswapV3 = new SwapHandlerUniswapV3(UNISWAP_V3_ROUTER_0_2);

        string memory outputKey = "data";
        uint256 blockNumber = block.number;
        string memory blockNumberStr = blockNumber.toString();
        vm.serializeAddress(outputKey, "swapHub", address(swapHub));
        // vm.serializeAddress(outputKey, "swapHandler1Inch", address(swapHandler1Inch));
        // vm.serializeAddress(outputKey, "swapHandlerUniAutoRouter", address(swapHandlerUniAutoRouter));
        string memory result = vm.serializeAddress(outputKey, "swapHandlerUniswapV3", address(swapHandlerUniswapV3));

        string memory location = "./lists/local/";
        vm.writeJson(result, string.concat(location, "swapHub-", blockNumberStr, ".json"));
        vm.writeJson(result, string.concat(location, "swapHub-latest.json"));
    }
}
