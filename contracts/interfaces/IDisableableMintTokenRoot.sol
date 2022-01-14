pragma ton-solidity >= 0.39.0;

interface IDisableableMintTokenRoot {
    /*
        @notice Disable 'mint' forever
        @dev Can be called only by rootOwner
        @dev This is an irreversible action
        @returns true
    */
    function disableMint() external responsible returns(bool);

    /*
        @notice Get mint disabled status
        @returns is 'disableMint' already called
    */
    function isMintDisabled() external view responsible returns(bool);
}
