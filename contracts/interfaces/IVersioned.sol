pragma ton-solidity >= 0.57.0;


interface IVersioned {
    /**
     * @dev Get the version of the contract
     */
    function version() external view responsible returns (uint32);
}
