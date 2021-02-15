pragma solidity >= 0.6.0;
pragma AbiHeader expire;

interface IPausable {
    function setPaused(bool value) external;
    function sendPausedCallbackTo(uint64 callback_id, address callback_addr) external;
}
