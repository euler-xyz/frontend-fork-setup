pragma solidity ^0.8.0;

import "forge-std/StdJson.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {WETH, USD, CRV, ENS, WBTC, WSTETH, STETH} from "euler-price-oracle-test/utils/EthereumAddresses.sol";
import {CHAINLINK_ETH_USD_FEED} from "euler-price-oracle-test/adapter/chainlink/ChainlinkAddresses.sol";
import {CHRONICLE_BTC_USD_FEED} from "euler-price-oracle-test/adapter/chronicle/ChronicleAddresses.sol";
import {PYTH, PYTH_ENS_USD_FEED} from "euler-price-oracle-test/adapter/pyth/PythFeeds.sol";
import {REDSTONE_CRV_USD_FEED} from "euler-price-oracle-test/adapter/redstone/RedstoneFeeds.sol";
import {ChainlinkOracle} from "euler-price-oracle/adapter/chainlink/ChainlinkOracle.sol";
import {ChronicleOracle} from "euler-price-oracle/adapter/chronicle/ChronicleOracle.sol";
import {LidoOracle} from "euler-price-oracle/adapter/lido/LidoOracle.sol";
import {PythOracle} from "euler-price-oracle/adapter/pyth/PythOracle.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {RedstoneCoreOracle} from "euler-price-oracle/adapter/redstone/RedstoneCoreOracle.sol";
import {AdapterRegistry} from "evk-periphery/OracleFactory/AdapterRegistry.sol";
import "openzeppelin-contracts/utils/Strings.sol";

contract DeployOracles is Script, Test {
    using stdJson for string;
    using Strings for uint256;

    string constant outputKey = "data";
    string resultAll = "";
    address deployer;

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

    function deployRouter() internal returns (EulerRouter) {
        EulerRouter router = new EulerRouter(deployer);

        string memory data = vm.toString(address(router));
        vm.serializeString(data, "name", router.name());
        vm.serializeAddress(data, "address", address(router));
        vm.serializeAddress(data, "fallbackOracle", router.fallbackOracle());
        string memory result = vm.serializeAddress(data, "governor", router.governor());
        resultAll = vm.serializeString(outputKey, data, result);
        return router;
    }

    function deployAdapterRegistry() internal returns (AdapterRegistry) {
        AdapterRegistry registry = new AdapterRegistry(deployer);

        string memory data = "adapterRegistry";
        string memory result = vm.serializeAddress(data, "address", address(registry));
        resultAll = vm.serializeString(outputKey, data, result);
        return registry;
    }

    function configureRouter(
        EulerRouter router,
        address[] memory bases,
        address[] memory quotes,
        address[] memory oracles,
        address[] memory resolvedVaults
    ) internal {
        require(bases.length == quotes.length && quotes.length == oracles.length);

        string memory data = vm.toString(address(router));
        string memory result = vm.serializeAddress(data, "resolvedVaults", resolvedVaults);

        uint256 length = bases.length;
        string memory configResult = "innerConfigs";
        string memory innerResult = "innerConfigResult";
        for (uint256 i = 0; i < length; ++i) {
            string memory key = vm.toString(oracles[i]);
            string memory object = "configObject";
            vm.serializeAddress(object, "base", bases[i]);
            vm.serializeAddress(object, "quote", quotes[i]);
            string memory configData = vm.serializeAddress(object, "oracle", oracles[i]);
            router.govSetConfig(bases[i], quotes[i], oracles[i]);
            innerResult = vm.serializeString(configResult, key, configData);
        }

        result = vm.serializeString(data, "configs", innerResult);

        for (uint256 i = 0; i < resolvedVaults.length; ++i) {
            router.govSetResolvedVault(resolvedVaults[i], true);
        }

        resultAll = vm.serializeString(outputKey, data, result);
    }

    function configureAdapterRegistry(
        AdapterRegistry registry,
        address[] memory bases,
        address[] memory quotes,
        address[] memory adapters
    ) internal {
        require(bases.length == quotes.length && quotes.length == adapters.length);

        string memory data = "adapterRegistry";

        uint256 length = bases.length;
        string memory configResult = "innerConfigs";
        string memory innerResult = "innerConfigResult";
        for (uint256 i = 0; i < length; ++i) {
            string memory key = vm.toString(adapters[i]);
            string memory object = "configObject";
            vm.serializeAddress(object, "base", bases[i]);
            vm.serializeAddress(object, "quote", quotes[i]);
            vm.serializeUint(object, "addedAt", block.timestamp);
            string memory configData = vm.serializeAddress(object, "oracle", adapters[i]);
            registry.addAdapter(adapters[i], bases[i], quotes[i]);
            innerResult = vm.serializeString(configResult, key, configData);
        }

        string memory result = vm.serializeString(data, "configs", innerResult);

        resultAll = vm.serializeString(outputKey, data, result);
    }

    function setUpDeployer(bool useMnemonic) internal {
        deployer = address(this);
        if (useMnemonic) {
            uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC"), 0);
            deployer = vm.addr(deployerPrivateKey);
            vm.startBroadcast(deployerPrivateKey);
        }
    }

    function execute(bool useMnemonic) public {
        setUpDeployer(useMnemonic);

        ChainlinkOracle chainlink_WETH_USD = deployChainlinkOracle(WETH, USD, CHAINLINK_ETH_USD_FEED, 24 hours);
        ChronicleOracle chronicle_BTC_USD = deployChronicleOracle(WBTC, USD, CHRONICLE_BTC_USD_FEED, 24 hours);
        LidoOracle lido_WSTETH_STETH = deployLidoOracle();
        PythOracle pyth_ENS_USD = deployPythOracle(PYTH, ENS, USD, PYTH_ENS_USD_FEED, 5 minutes, 500);
        RedstoneCoreOracle redstone_CRV_USD = deployRedstoneCoreOracle(CRV, USD, REDSTONE_CRV_USD_FEED, 8, 3 minutes);

        address[] memory bases = new address[](5);
        address[] memory quotes = new address[](5);
        address[] memory oracles = new address[](5);
        bases[0] = WETH;
        quotes[0] = USD;
        oracles[0] = address(chainlink_WETH_USD);

        bases[1] = WBTC;
        quotes[1] = USD;
        oracles[1] = address(chronicle_BTC_USD);

        bases[2] = WSTETH;
        quotes[2] = STETH;
        oracles[2] = address(lido_WSTETH_STETH);

        bases[3] = ENS;
        quotes[3] = USD;
        oracles[3] = address(pyth_ENS_USD);

        bases[4] = CRV;
        quotes[4] = USD;
        oracles[4] = address(redstone_CRV_USD);

        EulerRouter router = deployRouter();
        configureRouter(router, bases, quotes, oracles, new address[](0));

        AdapterRegistry adapterRegistry = deployAdapterRegistry();
        configureAdapterRegistry(adapterRegistry, bases, quotes, oracles);

        uint256 blockNumber = block.number;
        string memory blockNumberStr = blockNumber.toString();

        string memory location = "./lists/local/";
        vm.writeJson(resultAll, string.concat(location, "oracles-", blockNumberStr, ".json"));
        vm.writeJson(resultAll, string.concat(location, "oracles-latest.json"));
    }
}
