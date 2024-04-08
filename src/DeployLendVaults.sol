// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "forge-std/console2.sol";
import {FoundryRandom} from "foundry-random/FoundryRandom.sol";
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";
import {ProtocolConfig} from "euler-vault-kit/src/ProtocolConfig/ProtocolConfig.sol";
import {GenericFactory} from "euler-vault-kit/src/GenericFactory/GenericFactory.sol";
import {Base} from "euler-vault-kit/src/EVault/shared/Base.sol";
import {Initialize} from "euler-vault-kit/src/EVault/modules/Initialize.sol";
import {Token} from "euler-vault-kit/src/EVault/modules/Token.sol";
import {Vault} from "euler-vault-kit/src/EVault/modules/Vault.sol";
import {Borrowing} from "euler-vault-kit/src/EVault/modules/Borrowing.sol";
import {Liquidation} from "euler-vault-kit/src/EVault/modules/Liquidation.sol";
import {RiskManager} from "euler-vault-kit/src/EVault/modules/RiskManager.sol";
import {BalanceForwarder} from "euler-vault-kit/src/EVault/modules/BalanceForwarder.sol";
import {Governance} from "euler-vault-kit/src/EVault/modules/Governance.sol";
import {Dispatch} from "euler-vault-kit/src/EVault/Dispatch.sol";
import {EVault} from "euler-vault-kit/src/EVault/EVault.sol";
import {EVaultLens} from "euler-vault-kit/src/lens/EVaultLens.sol";
import {VaultInfo} from "euler-vault-kit/src/lens/LensTypes.sol";
import {MockPriceOracle} from "euler-vault-kit/test/mocks/MockPriceOracle.sol";
import {IRMTestDefault} from "euler-vault-kit/test/mocks/IRMTestDefault.sol";
import {TestERC20} from "euler-vault-kit/test/mocks/TestERC20.sol";
import "openzeppelin-contracts/utils/Strings.sol";
// --------------------------------------------------------------------------------------------------------
// What matters is the alphabetical order.
// As the JSON object is an unordered data structure but the tuple is an ordered one,
// we had to somehow give order to the JSON. The easiest way was to order the keys by alphabetical order.
// That means that in order to decode the JSON object correctly, you will need to define attributes of the
// struct with types that correspond to the values of the alphabetical order of the keys of the JSON.
// --------------------------------------------------------------------------------------------------------
// the order of the properties is important
// make sure that the dynamic props like string, bytes, arrays
// are last in the order of the json file and the struct
// this costed me a lot of debugging time so leaving it here as some useful info

struct TokenInfo {
    address addressInfo;
    uint256 chainId;
    uint256 decimals;
    string logoURI;
    string name;
    string symbol;
}

library StringUtils {
    function concat(string memory _a, string memory _b) internal pure returns (string memory) {
        bytes memory bytesA = bytes(_a);
        bytes memory bytesB = bytes(_b);
        bytes memory result = new bytes(bytesA.length + bytesB.length);
        uint256 k = 0;
        for (uint256 i = 0; i < bytesA.length; i++) {
            result[k++] = bytesA[i];
        }
        for (uint256 i = 0; i < bytesB.length; i++) {
            result[k++] = bytesB[i];
        }
        return string(result);
    }
}

/// @title Deployment script
/// @notice This script is used for deploying a couple vaults along with supporting contracts for testing purposes
contract DeployLendVaults is Script, Test, FoundryRandom {
    using stdJson for string;
    using Strings for uint256;
    using StringUtils for string;

    address internal constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant unitOfAccount = WETH_ADDRESS;
    // used for testing the script

    function testRun() public {
        execute(false);
    }

    function run() public {
        execute(true);
    }

    function execute(bool useMnemonic) public {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/data/forkTokenList.json");
        string memory json = vm.readFile(path);
        bytes memory rawData = json.parseRaw("$[*]"); // uses JSONPath to fetch the data
        TokenInfo[] memory tokenList = abi.decode(rawData, (TokenInfo[]));

        address deployer = address(this);
        if (useMnemonic) {
            uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC"), 0);
            deployer = vm.addr(deployerPrivateKey);
            vm.startBroadcast(deployerPrivateKey);
        }

        (
            GenericFactory factory,
            MockPriceOracle mockPriceOracle,
            IRMTestDefault interestRateModel,
            EthereumVaultConnector evc,
            EVaultLens lens
        ) = deployStructure(deployer);

        uint256 randomNum;
        // we will create a token for each token in the list
        EVault[] memory vaults = new EVault[](tokenList.length);

        for (uint256 i = 0; i < tokenList.length; i++) {
            console.log("addressInfo: ", tokenList[i].addressInfo);
            console.log("mockPriceOracle: ", address(mockPriceOracle));
            console.log("unitOfAccount: ", unitOfAccount);
            EVault vault = EVault(
                factory.createProxy(
                    true, abi.encodePacked(address(tokenList[i].addressInfo), mockPriceOracle, unitOfAccount)
                )
            );
            vault.setName(string(abi.encodePacked("Vault ", tokenList[i].name)));
            vault.setSymbol(string(abi.encodePacked("e", tokenList[i].symbol)));
            vault.setInterestRateModel(address(interestRateModel));
            vaults[i] = vault;
        }

        for (uint256 i = 0; i < vaults.length; i++) {
            uint256 randomVaultsCount = randomNumber(0, vaults.length - 1);
            for (uint256 j = 0; j < randomVaultsCount; j++) {
                uint256 randomVaultToSetLTV = randomNumber(0, vaults.length - 1);
                uint256 randomVaultToSetAsCollateral = randomNumber(0, vaults.length - 1);
                if (randomVaultToSetLTV == randomVaultToSetAsCollateral) {
                    continue; // self collateralization is not allowed
                }
                uint256 randomLTV = randomNumber(1, 10);
                vaults[randomVaultToSetLTV].setLTV(
                    address(vaults[randomVaultToSetAsCollateral]), uint16(((1e4) * randomLTV) / 10), 0
                );
                setPriceOracle(
                    unitOfAccount, mockPriceOracle, vaults, randomVaultToSetLTV, randomVaultToSetAsCollateral
                );
            }
        }

        string[] memory data = new string[](vaults.length);
        string memory outputKey = "data";
        string memory resultAll = "";
        for (uint256 i = 0; i < vaults.length; i++) {
            string memory vaultData = addressToString(address(vaults[i]));
            vm.serializeAddress(vaultData, "address", address(vaults[i]));
            vm.serializeAddress(vaultData, "asset", vaults[i].asset());
            vm.serializeString(vaultData, "name", vaults[i].name());
            vm.serializeString(vaultData, "symbol", vaults[i].symbol());
            vm.serializeAddress(vaultData, "unitOfAccount", unitOfAccount);
            vm.serializeAddress(vaultData, "interestRateModel", address(interestRateModel));
            vm.serializeAddress(vaultData, "evc", address(evc));
            vm.serializeAddress(vaultData, "lens", address(lens));
            string memory result = vm.serializeAddress(vaultData, "oracle", address(mockPriceOracle));
            resultAll = vm.serializeString(outputKey, vaultData, result);
        }
        uint256 blockNumber = block.number;
        string memory blockNumberStr = blockNumber.toString();
        string memory lendAppLocation = "./lists/local/";
        string memory outputPath =
            lendAppLocation.concat("vaultList").concat("-").concat(blockNumberStr).concat(".json");
        vm.writeJson(resultAll, outputPath);
        vm.writeJson(resultAll, lendAppLocation.concat("vaultList-latest.json"));
    }

    function setPriceOracle(
        address unitOfAccount,
        MockPriceOracle mockPriceOracle,
        EVault[] memory vaults,
        uint256 randomVaultToSetLTV,
        uint256 randomVaultToSetAsCollateral
    ) private {
        address assetVault = vaults[randomVaultToSetAsCollateral].asset(); // get the asset of the controller vault
        address assetCollateral = vaults[randomVaultToSetLTV].asset(); // get the asset of the collateral vault
        uint256 randomPriceFactorAssetVault = randomNumber(1, 100);
        uint256 randomPriceFactorAssetCollateral = randomNumber(1, 100);
        MockPriceOracle(mockPriceOracle).setPrice(
            assetVault, unitOfAccount, randomPriceFactorAssetVault * uint256(1e18)
        );
        MockPriceOracle(mockPriceOracle).setPrice(
            assetCollateral, unitOfAccount, randomPriceFactorAssetCollateral * uint256(1e18)
        );
    }

    function deployStructure(address deployer)
        public
        returns (
            GenericFactory factory,
            MockPriceOracle mockPriceOracle,
            IRMTestDefault interestRateModel,
            EthereumVaultConnector evc,
            EVaultLens lens
        )
    {
        // deploy the EVC
        evc = new EthereumVaultConnector();

        // deploy the reward streams contract
        address rewardStreams = address(0); //address(new StakingFreeRewardStreams(IEVC(evc), 10 days));

        // deploy the protocol config
        address protocolConfig = address(new ProtocolConfig(deployer, deployer));

        // define the integrations struct
        Base.Integrations memory integrations =
            Base.Integrations(address(evc), protocolConfig, rewardStreams, PERMIT2_ADDRESS);

        // deploy the EVault modules
        Dispatch.DeployedModules memory modules = Dispatch.DeployedModules({
            initialize: address(new Initialize(integrations)),
            token: address(new Token(integrations)),
            vault: address(new Vault(integrations)),
            borrowing: address(new Borrowing(integrations)),
            liquidation: address(new Liquidation(integrations)),
            riskManager: address(new RiskManager(integrations)),
            balanceForwarder: address(new BalanceForwarder(integrations)),
            governance: address(new Governance(integrations))
        });

        // deploy the factory
        factory = new GenericFactory(deployer);

        // set up the factory deploying the EVault implementation
        factory.setImplementation(address(new EVault(integrations, modules)));

        // deploy the price oracle
        mockPriceOracle = new MockPriceOracle();

        // deploy a default interest rate model
        interestRateModel = new IRMTestDefault();

        // deploy the lens
        lens = new EVaultLens();
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