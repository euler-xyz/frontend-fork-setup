pragma solidity ^0.8.0;

import "forge-std/StdJson.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {
    WETH,
    USD,
    CRV,
    ENS,
    WBTC,
    WSTETH,
    STETH
} from "euler-price-oracle-test/utils/EthereumAddresses.sol";
import {CHAINLINK_ETH_USD_FEED} from "euler-price-oracle-test/adapter/chainlink/ChainlinkAddresses.sol";
import {CHRONICLE_BTC_USD_FEED} from "euler-price-oracle-test/adapter/chronicle/ChronicleAddresses.sol";
import {PYTH, PYTH_ENS_USD_FEED} from "euler-price-oracle-test/adapter/pyth/PythFeeds.sol";
import {REDSTONE_CRV_USD_FEED} from "euler-price-oracle-test/adapter/redstone/RedstoneFeeds.sol";
import {ChainlinkOracle} from "euler-price-oracle/adapter/chainlink/ChainlinkOracle.sol";
import {ChronicleOracle} from "euler-price-oracle/adapter/chronicle/ChronicleOracle.sol";
import {LidoOracle} from "euler-price-oracle/adapter/lido/LidoOracle.sol";
import {PythOracle} from "euler-price-oracle/adapter/pyth/PythOracle.sol";
import {RedstoneCoreOracle} from "euler-price-oracle/adapter/redstone/RedstoneCoreOracle.sol";
import "openzeppelin-contracts/utils/Strings.sol";

contract DeployOracles is Script, Test {
    using stdJson for string;
    using Strings for uint256;

    string constant outputKey = "data";
    string resultAll = "";

    function run() public {
        execute(true);
    }

    function deployChainlinkOracle(address base, address quote, address feed, uint256 maxStaleness)
        internal
        returns (ChainlinkOracle)
    {
        ChainlinkOracle oracle = new ChainlinkOracle(base, quote, feed, maxStaleness);

        string memory data = vm.toString(address(oracle));
        vm.serializeString(data, "name", oracle.name());
        vm.serializeAddress(data, "address", address(oracle));
        vm.serializeAddress(data, "base", oracle.base());
        vm.serializeAddress(data, "quote", oracle.quote());
        vm.serializeAddress(data, "feed", oracle.feed());
        string memory result = vm.serializeUint(data, "maxStaleness", oracle.maxStaleness());
        resultAll = vm.serializeString(outputKey, data, result);
        return oracle;
    }

    function deployChronicleOracle(address base, address quote, address feed, uint256 maxStaleness)
        internal
        returns (ChronicleOracle)
    {
        ChronicleOracle oracle = new ChronicleOracle(base, quote, feed, maxStaleness);

        string memory data = vm.toString(address(oracle));
        vm.serializeString(data, "name", oracle.name());
        vm.serializeAddress(data, "address", address(oracle));
        vm.serializeAddress(data, "base", oracle.base());
        vm.serializeAddress(data, "quote", oracle.quote());
        vm.serializeAddress(data, "feed", oracle.feed());
        string memory result = vm.serializeUint(data, "maxStaleness", oracle.maxStaleness());
        resultAll = vm.serializeString(outputKey, data, result);
        return oracle;
    }

    function deployLidoOracle() internal returns (LidoOracle) {
        LidoOracle oracle = new LidoOracle();

        string memory data = vm.toString(address(oracle));
        vm.serializeString(data, "name", oracle.name());
        vm.serializeAddress(data, "base", oracle.WSTETH());
        vm.serializeAddress(data, "quote", oracle.STETH());
        string memory result = vm.serializeAddress(data, "address", address(oracle));
        resultAll = vm.serializeString(outputKey, data, result);
        return oracle;
    }

    function deployPythOracle(
        address pyth,
        address base,
        address quote,
        bytes32 feedId,
        uint256 maxStaleness,
        uint256 maxConfWidth
    ) internal returns (PythOracle) {
        PythOracle oracle = new PythOracle(pyth, base, quote, feedId, maxStaleness, maxConfWidth);

        string memory data = vm.toString(address(oracle));
        vm.serializeString(data, "name", oracle.name());
        vm.serializeAddress(data, "address", address(oracle));
        vm.serializeAddress(data, "base", oracle.base());
        vm.serializeAddress(data, "quote", oracle.quote());
        vm.serializeBytes32(data, "feedId", oracle.feedId());
        vm.serializeUint(data, "maxStaleness", oracle.maxStaleness());
        string memory result = vm.serializeUint(data, "maxConfWidth", oracle.maxConfWidth());
        resultAll = vm.serializeString(outputKey, data, result);
        return oracle;
    }

    function deployRedstoneCoreOracle(
        address base,
        address quote,
        bytes32 feedId,
        uint8 feedDecimals,
        uint256 maxStaleness
    ) internal returns (RedstoneCoreOracle) {
        RedstoneCoreOracle oracle = new RedstoneCoreOracle(base, quote, feedId, feedDecimals, maxStaleness);

        string memory data = vm.toString(address(oracle));
        vm.serializeString(data, "name", oracle.name());
        vm.serializeAddress(data, "address", address(oracle));
        vm.serializeAddress(data, "base", oracle.base());
        vm.serializeAddress(data, "quote", oracle.quote());
        vm.serializeBytes32(data, "feedId", oracle.feedId());
        vm.serializeUint(data, "feedId", oracle.feedDecimals());
        string memory result = vm.serializeUint(data, "maxStaleness", oracle.maxStaleness());
        resultAll = vm.serializeString(outputKey, data, result);
        return oracle;
    }

    function execute(bool useMnemonic) public {
        address deployer = address(this);
        if (useMnemonic) {
            uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC"), 0);
            deployer = vm.addr(deployerPrivateKey);
            vm.startBroadcast(deployerPrivateKey);
        }

        ChainlinkOracle chainlink_WETH_USD = deployChainlinkOracle(WETH, USD, CHAINLINK_ETH_USD_FEED, 24 hours);

        ChronicleOracle chronicle_BTC_USD = deployChronicleOracle(WBTC, USD, CHRONICLE_BTC_USD_FEED, 24 hours);

        LidoOracle lido_WSTETH_STETH = deployLidoOracle();

        PythOracle pyth_ENS_USD = deployPythOracle(PYTH, ENS, USD, PYTH_ENS_USD_FEED, 5 minutes, 500);

        RedstoneCoreOracle redstone_CRV_USD = deployRedstoneCoreOracle(CRV, USD, REDSTONE_CRV_USD_FEED, 8, 3 minutes);

        address[5] memory oracles = [
            address(chainlink_WETH_USD),
            address(chronicle_BTC_USD),
            address(lido_WSTETH_STETH),
            address(pyth_ENS_USD),
            address(redstone_CRV_USD)
        ];

        uint256 blockNumber = block.number;
        string memory blockNumberStr = blockNumber.toString();

        string memory location = "./lists/local/";
        vm.writeJson(resultAll, string.concat(location, "oracles-", blockNumberStr, ".json"));
        vm.writeJson(resultAll, string.concat(location, "oracles-latest.json"));
    }
}
