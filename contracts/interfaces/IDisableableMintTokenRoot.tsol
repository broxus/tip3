pragma ton-solidity >= 0.57.0;

/**
 * @dev Interface defines a contract that has functions to permanently disable
 * the minting of new tokens and check
 * the status of the ability to mint new tokens.
 */
interface IDisableableMintTokenRoot {
    /**
     * @notice Disable 'mint' forever
     * @dev This is an irreversible action
     * @return true
     *
     * Precondition:
     *  - sender MUST be rootOwner
     *
     * Postcondition:
     *  - Disable minting forever
    */
    function disableMint() external responsible returns (bool);

    /**
     * @notice Сheck if the minting of new tokens has already been disabled
     * @return is 'disableMint' already called
    */
    function mintDisabled() external view responsible returns (bool);
}
