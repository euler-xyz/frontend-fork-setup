// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {BasePerspective} from "evk-periphery/Perspectives/implementation/BasePerspective.sol";

contract MockPerspective is BasePerspective {
    string internal _name;
    /// @notice Creates a new EscrowSingletonPerspective instance.
    /// @param vaultFactory_ The address of the GenericFactory contract.
    constructor(address vaultFactory_) BasePerspective(vaultFactory_) {}

    /// @inheritdoc BasePerspective
    function name() public view virtual override returns (string memory) {
        return _name;
    }
}
