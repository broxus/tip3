pragma ton -solidity >= 0.56.0;

import "../TokenRoot.sol";
import "../additional/Wallet.sol";


struct CallbackData {
    address oldOwner;
    address newOwner;
    address remainingGasTo;
    TvmCell payload;
}


contract TestRootTransferCallback is Wallet, ITransferTokenRootOwnershipCallback {
    uint16 IS_NOT_ROOT = 10001;

    address public _root;
    CallbackData public _callback;

    constructor() public {
        tvm.accept();
    }

    function setRoot(address root) public {
        tvm.accept();
        _root = root;
    }

    function onTransferTokenRootOwnership(
        address oldOwner,
        address newOwner,
        address remainingGasTo,
        TvmCell payload
    ) public override {
//        require(msg.sender == _root, IS_NOT_ROOT);
        _callback = CallbackData(oldOwner, newOwner, remainingGasTo, payload);
    }

}
