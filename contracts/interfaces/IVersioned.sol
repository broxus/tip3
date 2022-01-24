pragma ton-solidity >= 0.39.0;


interface IVersioned {
    function version() external view responsible returns(uint32);
}
