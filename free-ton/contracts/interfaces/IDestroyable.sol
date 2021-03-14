pragma solidity >= 0.6.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

interface IDestroyable {
    function destroy(address gas_dest) external;
}
