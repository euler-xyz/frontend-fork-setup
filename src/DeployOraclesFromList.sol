pragma solidity ^0.8.0;

import "forge-std/StdJson.sol";
import {console2} from "forge-std/console2.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {AdapterRegistry} from "evk-periphery/OracleFactory/AdapterRegistry.sol";
import {DeployOracles} from "./DeployOracles.sol";
import "openzeppelin-contracts/utils/Strings.sol";

contract DeployOraclesFromList is DeployOracles {
    using stdJson for string;
    using Strings for uint256;

    uint256 internal constant HEARTBEAT_GRACE_PERIOD = 5 minutes;
    uint256 internal constant REDSTONE_CORE_MAX_STALENESS = 5 minutes;
    uint256 internal constant PYTH_MAX_STALENESS = 5 minutes;
    uint256 internal constant PYTH_MAX_CONF_WIDTH = 500;
    address internal constant PYTH = 0x4305FB66699C3B2702D4d05CF36551390A4c69C6;

    struct ChainlinkOracleDefinition {
        address base;
        uint256 chainId;
        uint256 deviationThreshold;
        address feed;
        uint256 heartbeat;
        bool inverse;
        string kind;
        address quote;
    }

    struct ChronicleOracleDefinition {
        address base;
        uint256 chainId;
        uint256 deviationThreshold;
        address feed;
        uint256 heartbeat;
        bool inverse;
        string kind;
        address quote;
    }

    struct RedstoneCoreOracleDefinition {
        address base;
        uint256 chainId;
        uint8 decimals;
        bytes32 feedId;
        bool inverse;
        string kind;
        address quote;
    }

    struct PythOracleDefinition {
        address base;
        uint256 chainId;
        bytes32 feedId;
        bool inverse;
        string kind;
        address quote;
    }

    struct LidoOracleDefinition {
        address base;
        uint256 chainId;
        bool inverse;
        string kind;
        address quote;
    }

    function execute(bool useMnemonic) public override {
        setUpDeployer(useMnemonic);

        string memory root = vm.projectRoot();
        string memory oracleListPath = "/data/oracleList.json";
        string memory path = string.concat(root, oracleListPath);
        string memory json = vm.readFile(path);

        uint256 numOracles = json.readUint(".numOracles");
        numOracles = 242;
        console2.log("[DeployOracles] Deploying %s oracles from oracle list at %s", numOracles, oracleListPath);

        EulerRouter router = deployRouter();
        AdapterRegistry adapterRegistry = deployAdapterRegistry();

        address[] memory bases = new address[](numOracles);
        address[] memory quotes = new address[](numOracles);
        address[] memory oracles = new address[](numOracles);

        for (uint256 i = 0; i < numOracles; ++i) {
            string memory key = string.concat(".oracles[", vm.toString(i), "]");
            string memory kind = json.readString(string.concat(key, ".kind"));
            bases[i] = json.readAddress(string.concat(key, ".base"));
            quotes[i] = json.readAddress(string.concat(key, ".quote"));

            console2.log("[DeployOracles] Deploying %s oracle (%s/%s)", kind, i + 1, numOracles);

            bytes memory oracleDefinitionRaw = json.parseRaw(key);
            if (strEq(kind, "Chainlink")) {
                ChainlinkOracleDefinition memory oracleDefinition =
                    abi.decode(oracleDefinitionRaw, (ChainlinkOracleDefinition));

                oracles[i] = address(
                    deployChainlinkOracle(
                        oracleDefinition.base,
                        oracleDefinition.quote,
                        oracleDefinition.feed,
                        oracleDefinition.heartbeat + HEARTBEAT_GRACE_PERIOD
                    )
                );
            } else if (strEq(kind, "Chronicle")) {
                ChronicleOracleDefinition memory oracleDefinition =
                    abi.decode(oracleDefinitionRaw, (ChronicleOracleDefinition));

                oracles[i] = address(
                    deployChronicleOracle(
                        oracleDefinition.base,
                        oracleDefinition.quote,
                        oracleDefinition.feed,
                        oracleDefinition.heartbeat + HEARTBEAT_GRACE_PERIOD
                    )
                );
            } else if (strEq(kind, "RedstoneCore")) {
                RedstoneCoreOracleDefinition memory oracleDefinition =
                    abi.decode(oracleDefinitionRaw, (RedstoneCoreOracleDefinition));
                oracles[i] = address(
                    deployRedstoneCoreOracle(
                        oracleDefinition.base,
                        oracleDefinition.quote,
                        oracleDefinition.feedId,
                        oracleDefinition.decimals,
                        REDSTONE_CORE_MAX_STALENESS
                    )
                );
            } else if (strEq(kind, "Pyth")) {
                PythOracleDefinition memory oracleDefinition = abi.decode(oracleDefinitionRaw, (PythOracleDefinition));
                oracles[i] = address(
                    deployPythOracle(
                        PYTH,
                        oracleDefinition.base,
                        oracleDefinition.quote,
                        oracleDefinition.feedId,
                        PYTH_MAX_STALENESS,
                        PYTH_MAX_CONF_WIDTH
                    )
                );
            } else if (strEq(kind, "Lido")) {
                abi.decode(oracleDefinitionRaw, (LidoOracleDefinition));
                oracles[i] = address(deployLidoOracle());
            } else {
                console2.log('[DeployOracles] Found unknown oracle kind in oracle list: "%s"', kind);
            }
        }

        configureRouter(router, bases, quotes, oracles, new address[](0));
        configureAdapterRegistry(adapterRegistry, bases, quotes, oracles);
        writeDeploymentResult();
    }

    function strEq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
