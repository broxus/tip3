pragma ton-solidity >= 0.39.0;


interface IDestroyable {
    function destroy(address gas_dest) external;
}
