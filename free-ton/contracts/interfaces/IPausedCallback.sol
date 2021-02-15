pragma solidity >= 0.6.0;
pragma AbiHeader expire;

interface IPausedCallback {
    function pausedCallback(uint64 callback_id, bool value) external;
}
