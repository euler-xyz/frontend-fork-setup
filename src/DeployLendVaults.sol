// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "forge-std/console2.sol";

import {FoundryRandom} from "foundry-random/FoundryRandom.sol";
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";
import {TrackingRewardStreams} from "reward-streams/TrackingRewardStreams.sol";
import {ProtocolConfig} from "euler-vault-kit/src/ProtocolConfig/ProtocolConfig.sol";
import {GenericFactory} from "euler-vault-kit/src/GenericFactory/GenericFactory.sol";
import {Base} from "euler-vault-kit/src/EVault/shared/Base.sol";
import {SequenceRegistry} from "euler-vault-kit/src/SequenceRegistry/SequenceRegistry.sol";
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
import {IEVault, IERC20} from "euler-vault-kit/src/EVault/IEVault.sol";
import {AccountLens} from "euler-vault-kit/src/lens/AccountLens.sol";
import {VaultLens} from "euler-vault-kit/src/lens/VaultLens.sol";
import {VaultInfo} from "euler-vault-kit/src/lens/LensTypes.sol";
import {IRMTestDefault} from "euler-vault-kit/test/mocks/IRMTestDefault.sol";
import {TestERC20} from "euler-vault-kit/test/mocks/TestERC20.sol";
import {MockPriceOracle} from "./mocks/MockPriceOracle.sol";
import "openzeppelin-contracts/utils/Strings.sol";

// --------------------------------------------------------------------------------------------------------
// What matters is the alphabetical order.
// As the JSON object is an unordered data structure but the tuple is an ordered one,
// we had to somehow give order to the JSON. The easiest way was to order the keys by alphabetical order.
// That means that in order to decode the JSON object correctly, you will need to define attributes of the
// struct with types that correspond to the values of the alphabetical order of the keys of the JSON.
struct TokenInfo {
    address addressInfo;
    uint256 chainId;
    uint256 decimals;
    string logoURI;
    string name;
    string symbol;
}

/// @title Deployment script
/// @notice This script is used for deploying a couple vaults along with supporting contracts for testing purposes
contract DeployLendVaults is Script, Test, FoundryRandom {
    using stdJson for string;
    using Strings for uint256;

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
            TrackingRewardStreams rewardStreams,
            VaultLens vaultLens,
            AccountLens accountLens
        ) = deployStructure(deployer);

        // we will create a token for each token in the list
        EVault[] memory vaults = new EVault[](tokenList.length);

        for (uint256 i = 0; i < tokenList.length; i++) {
            console.log("addressInfo: ", tokenList[i].addressInfo);
            console.log("mockPriceOracle: ", address(mockPriceOracle));
            console.log("unitOfAccount: ", unitOfAccount);
            EVault vault = EVault(
                factory.createProxy(
                    address(0),
                    false,
                    abi.encodePacked(address(tokenList[i].addressInfo), mockPriceOracle, unitOfAccount)
                )
            );
            vault.setInterestRateModel(address(interestRateModel));
            // approveAndDepositToVault(address(vault), tokenList[i].addressInfo, 100e18, deployer);
            vaults[i] = vault;
        }

        for (uint256 i = 0; i < vaults.length; i++) {
            uint256 randomVaultsCount = randomNumber(0, vaults.length - 1);
            for (uint256 j = 0; j < randomVaultsCount; j++) {
                EVault randomController = vaults[randomNumber(0, vaults.length - 1)];
                EVault randomCollateral = vaults[randomNumber(0, vaults.length - 1)];

                if (address(randomController) == address(randomCollateral)) {
                    continue; // self collateralization is not allowed
                }

                uint256 randomLTV = randomNumber(10, 100);
                randomController.setLTV(
                    address(randomCollateral),
                    uint16(((1e4) * (randomLTV - 5)) / 100), // borrowLTV
                    uint16(((1e4) * randomLTV) / 100), // liquidationLTV
                    0
                );

                setPriceOracle(mockPriceOracle, randomController, randomCollateral);
            }
        }

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
            vm.serializeAddress(vaultData, "genericFactory", address(factory));
            vm.serializeAddress(vaultData, "rewardStreams", address(rewardStreams));
            vm.serializeAddress(vaultData, "vaultLens", address(vaultLens));
            vm.serializeAddress(vaultData, "accountLens", address(accountLens));
            string memory result = vm.serializeAddress(vaultData, "oracle", address(mockPriceOracle));
            resultAll = vm.serializeString(outputKey, vaultData, result);
        }
        uint256 blockNumber = block.number;
        string memory blockNumberStr = blockNumber.toString();
        string memory lendAppLocation = "./lists/local/";
        string memory outputPath = string.concat(lendAppLocation, "vaultList", "-", blockNumberStr, ".json");
        vm.writeJson(resultAll, outputPath);
        // vm.writeJson(resultAll, lendAppLocation.concat("vaultList-latest.json"));
    }

    function approveAndDepositToVault(address _vault, address _token, uint256 _amount, address _receiver) private {
        IERC20 token = IERC20(_token);
        IEVault vault = IEVault(_vault);
        token.approve(_vault, _amount);
        vault.deposit(_amount, _receiver);
    }

    function setPriceOracle(MockPriceOracle mockPriceOracle, EVault controller, EVault collateral) private {
        address quoteAsset = controller.unitOfAccount();
        // uint256 randomPriceFactorAssetVault = randomNumber(1, 100);
        // uint256 randomPriceFactorAssetCollateral = randomNumber(1, 100);
        mockPriceOracle.setPrice(controller.asset(), quoteAsset, 1e18);
        mockPriceOracle.setResolvedVault(address(collateral), true);
        mockPriceOracle.setPrice(collateral.asset(), quoteAsset, 1e18);
    }

    function deployStructure(address deployer)
        public
        returns (
            GenericFactory factory,
            MockPriceOracle mockPriceOracle,
            IRMTestDefault interestRateModel,
            EthereumVaultConnector evc,
            TrackingRewardStreams rewardStreams,
            VaultLens vaultLens,
            AccountLens accountLens
        )
    {
        // deploy the EVC
        evc = new EthereumVaultConnector();

        // deploy the reward streams contract
        rewardStreams = new TrackingRewardStreams(address(evc), 14 days);

        // deploy the protocol config
        address protocolConfig = address(new ProtocolConfig(deployer, deployer));

        // deploy the sequence registry
        address sequenceRegistry = address(new SequenceRegistry());

        // define the integrations struct
        Base.Integrations memory integrations =
            Base.Integrations(address(evc), protocolConfig, sequenceRegistry, address(rewardStreams), PERMIT2_ADDRESS);

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

        // deploy the lenses
        vaultLens = new VaultLens();
        accountLens = new AccountLens();
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
