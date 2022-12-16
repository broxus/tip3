pragma ton-solidity >= 0.57.0;

/**
 * @dev Interface extends contract interface adding destroy function.
 */
interface IDestroyable {
    /**
     * @notice Destroys the contract.
     * @notice This function is virtual and can be overridden.
     * @param remainingGasTo The address to which the remaining gas will be sent.
     */
    function destroy(address remainingGasTo) external;
}
