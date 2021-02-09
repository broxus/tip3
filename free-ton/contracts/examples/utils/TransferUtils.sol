pragma solidity >= 0.6.0;
pragma AbiHeader expire;


contract TransferUtils {
    modifier transferAfter(address receiver, uint128 value) {
        _;
        receiver.transfer({ value: value });
    }

    modifier transferAfterRest(address receiver) {
        _;
        receiver.transfer({ flag:64, value: 0 });
    }

    function transferAll(address receiver) internal pure {
        receiver.transfer({ flag: 128, value: 0 });
    }
}
