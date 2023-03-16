pragma ton-solidity >= 0.57.0;

/**
 * @dev This interface defines a {deployRoot} function that creates
 * a new token root contract.
 */
interface ITokenFactory {

    /**
     * @dev Creates a new token root contract
     *
     * @param name - name of the token
     * @param symbol - symbol of the token
     * @param decimals - number of decimals of the token
     * @param owner - owner of the token
     * @param initialSupplyTo - address to mint initial supply to
     * @param initialSupply - initial supply
     * @param deployWalletValue - value to be sent to the wallet contract
     * @param mintDisabled - flag to disable minting
     * @param burnByRootDisabled - flag to disable burning by root
     * @param burnPaused - flag to pause burning
     * @param remainingGasTo - address to send remaining gas to
     * @param upgradeable - flag to deploy upgradeable token
     * @return address of the deployed token root
    */
    function deployRoot(
        string name,                    // static
        string symbol,                  // static
        uint8 decimals,                 // static
        address owner,                  // static
        address initialSupplyTo,        // constructor
        uint128 initialSupply,          // constructor
        uint128 deployWalletValue,      // constructor
        bool mintDisabled,              // constructor
        bool burnByRootDisabled,        // constructor
        bool burnPaused,                // constructor
        address remainingGasTo,         // constructor
        bool upgradeable
    ) external responsible returns (address);

}
