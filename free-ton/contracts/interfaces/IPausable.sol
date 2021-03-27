pragma ton-solidity ^0.38.2;
pragma AbiHeader expire;

interface IPausable {
    function setPaused(bool value) external;
    function sendPausedCallbackTo(uint64 callback_id, address callback_addr) external;
}
