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
import "openzeppelin-contracts/utils/Strings.sol";

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
        vm.serializeString(clData, "name", chainlink_WETH_USD.name());
        vm.serializeAddress(clData, "address", address(chainlink_WETH_USD));
        vm.serializeAddress(clData, "base", chainlink_WETH_USD.base());
        vm.serializeAddress(clData, "quote", chainlink_WETH_USD.quote());
        vm.serializeAddress(clData, "feed", chainlink_WETH_USD.feed());
        string memory result = vm.serializeUint(clData, "maxStaleness", chainlink_WETH_USD.maxStaleness());
        resultAll = vm.serializeString(outputKey, clData, result);

        string memory crData = addressToString(address(chronicle_BTC_USD));
        vm.serializeString(crData, "name", chronicle_BTC_USD.name());
        vm.serializeAddress(crData, "address", address(chronicle_BTC_USD));
        vm.serializeAddress(crData, "base", chronicle_BTC_USD.base());
        vm.serializeAddress(crData, "quote", chronicle_BTC_USD.quote());
        vm.serializeAddress(crData, "feed", chronicle_BTC_USD.feed());
        result = vm.serializeUint(crData, "maxStaleness", chronicle_BTC_USD.maxStaleness());
        resultAll = vm.serializeString(outputKey, crData, result);

        address[5] memory oracles = [address(chainlink_WETH_USD), address(chronicle_BTC_USD), address(lido_WSTETH_STETH), address(pyth_ENS_USD), address(redstone_CRV_USD)];

        uint256 blockNumber = block.number;
        string memory blockNumberStr = blockNumber.toString();

        string memory location = "./lists/local/";
        vm.writeJson(result, string.concat(location, "oracles-", blockNumberStr, ".json"));
        vm.writeJson(result, string.concat(location, "oracles-latest.json"));
    }

    function addressToString(address _addr) public pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint256(uint8(value[i + 12] >> 4))];
            str[3 + i * 2] = alphabet[uint256(uint8(value[i + 12] & 0x0f))];
        }
        return string(str);
    }
}
