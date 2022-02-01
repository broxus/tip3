pragma ton-solidity >= 0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./TokenRootBase.sol";
import "../interfaces/ITransferableOwnership.sol";

abstract contract TokenRootTransferableOwnershipBase is TokenRootBase, ITransferableOwnership {

    function transferOwnership(
        address newOwner,
        address remainingGasTo,
        mapping(address => CallbackParams) callbacks
    ) override external onlyRootOwner {
        _transferOwnership(newOwner, remainingGasTo, callbacks);
    }

}
