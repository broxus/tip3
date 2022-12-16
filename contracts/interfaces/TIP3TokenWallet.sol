pragma ton-solidity >= 0.57.0;

/**
 * @dev Interface of the TIP-3.1 TokenWallet contract.
 */
interface TIP3TokenWallet {
    /**
     * @notice Returns the current root contract of the wallet.
     */
    function root() external view responsible returns (address);

    /**
     * @notice Returns the current balance of the wallet.
     */
    function balance() external view responsible returns (uint128);

    /**
     * @notice Returns the wallet code.
     */
    function walletCode() external view responsible returns (TvmCell);
}
