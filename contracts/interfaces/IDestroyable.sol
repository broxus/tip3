pragma ton-solidity >= 0.56.0;

interface IDestroyable {
    function destroy(address sendGasTo) external;
}
