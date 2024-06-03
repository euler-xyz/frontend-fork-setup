pragma solidity ^0.8.0;

import "forge-std/StdJson.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {SwapHub} from "swaps/SwapHub.sol";
import {WETH, USDC, USDT, USD, DAI, CRV, ENS, WBTC, WSTETH, STETH} from "euler-price-oracle-test/utils/EthereumAddresses.sol";
import {CHAINLINK_ETH_USD_FEED} from "euler-price-oracle-test/adapter/chainlink/ChainlinkAddresses.sol";
import {CHRONICLE_BTC_USD_FEED} from "euler-price-oracle-test/adapter/chronicle/ChronicleAddresses.sol";
import {PYTH, PYTH_ENS_USD_FEED} from "euler-price-oracle-test/adapter/pyth/PythFeeds.sol";
import {REDSTONE_CRV_USD_FEED} from "euler-price-oracle-test/adapter/redstone/RedstoneFeeds.sol";
import {ChainlinkOracle} from "euler-price-oracle/adapter/chainlink/ChainlinkOracle.sol";
import {ChronicleOracle} from "euler-price-oracle/adapter/chronicle/ChronicleOracle.sol";
import {LidoOracle} from "euler-price-oracle/adapter/lido/LidoOracle.sol";
import {PythOracle} from "euler-price-oracle/adapter/pyth/PythOracle.sol";
import {RedstoneCoreOracle} from "euler-price-oracle/adapter/redstone/RedstoneCoreOracle.sol";

contract DeployOracles is Script, Test {
    using stdJson for string;
    using Strings for uint256;

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

        ChainlinkOracle chainlink_WETH_USD = new ChainlinkOracle(
            WETH,
            USD,
            CHAINLINK_ETH_USD_FEED,
            24 hours
        );

        ChronicleOracle chronicle_BTC_USD = new ChronicleOracle(
            WBTC,
            USD,
            CHRONICLE_BTC_USD_FEED,
            24 hours
        );

        LidoOracle lido_WSTETH_STETH = new LidoOracle();

        PythOracle pyth_ENS_USD = new PythOracle(
            PYTH,
            ENS,
            USD,
            PYTH_ENS_USD_FEED,
            5 minutes,
            500
        );

        RedstoneCoreOracle redstone_CRV_USD = new RedstoneCoreOracle(
            CRV,
            USD,
            REDSTONE_CRV_USD_FEED,
            8,
            3 minutes
        );

        string memory outputKey = "data";
        string memory resultAll = "";

        string memory clData = addressToString(address(chainlink_WETH_USD));
        vm.serializeAddress(clData, "name", chainlink_WETH_USD.name());
        vm.serializeAddress(clData, "address", address(chainlink_WETH_USD));
        vm.serializeAddress(clData, "base", chainlink_WETH_USD.base());
        vm.serializeAddress(clData, "quote", chainlink_WETH_USD.quote());
        vm.serializeAddress(clData, "feed", chainlink_WETH_USD.feed());
        string memory result = vm.serializeUint256(clData, "maxStaleness", chainlink_WETH_USD.maxStaleness());
        resultAll = vm.serializeString(outputKey, clData, result);

        string memory crData = addressToString(address(chronicle_BTC_USD));
        vm.serializeAddress(clData, "name", chronicle_BTC_USD.name());
        vm.serializeAddress(clData, "address", address(chronicle_BTC_USD));
        vm.serializeAddress(clData, "base", chronicle_BTC_USD.base());
        vm.serializeAddress(clData, "quote", chronicle_BTC_USD.quote());
        vm.serializeAddress(clData, "feed", chronicle_BTC_USD.feed());
        vm.serializeUint256(clData, "maxStaleness", chronicle_BTC_USD.maxStaleness());
        resultAll = vm.serializeString(outputKey, clData, result);

        address[5] memory oracles = [address(chainlink_WETH_USD), address(chronicle_BTC_USD), address(lido_WSTETH_STETH), address(pyth_ENS_USD), address(redstone_CRV_USD)];

        uint256 blockNumber = block.number;
        string memory blockNumberStr = blockNumber.toString();
        vm.serializeAddress(outputKey, "swapHub", address(swapHub));

        string memory location = "./lists/local/";
        vm.writeJson(result, string.concat(location, "oracles-", blockNumberStr, ".json"));
        vm.writeJson(result, string.concat(location, "oracles-latest.json"));
    }
}
