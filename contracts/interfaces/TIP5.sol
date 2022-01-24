pragma ton-solidity >= 0.39.0;

interface TIP5 {

    /// @notice Query if a contract implements an interface
    /// @param interfaceID The interface identifier, as specified in TIP5
    /// @dev Interface identification is specified in TIP5.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise

    function supportsInterface(bytes4 interfaceID) external view responsible returns(bool);
}
