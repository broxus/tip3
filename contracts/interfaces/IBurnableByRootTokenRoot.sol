pragma ton-solidity >= 0.57.0;

import "./IBurnPausableTokenRoot.sol";

/**
 * @dev Interface for disabling the ability of the TokenRoot contract to burn
 * tokens on behalf of any TokenWallet contract.
 *
 * Chain of calls:
 *
 * rootOwner -> IBurnableByRootTokenRoot(root).burnTokens(...) ->
 *              IBurnableByRootTokenWallet(wallet).burnByRoot(...) ->
 *              ITokenRoot(root).acceptBurn(...) ->
 *              IAcceptTokensBurnCallback(callbackTo).onAcceptTokensBurn(...) -> ...
 */
interface IBurnableByRootTokenRoot {

    /**
     * @notice Allows for rootOwner burn tokens from any TokenWallet.
     * @dev This method can be disabled using `disableBurnByRoot()`
     * @dev Can be called only by rootOwner
     *
     * @param amount Amount tokens to burn
     * @param walletOwner Address of TokenWallet owner.
     * @param remainingGasTo Address of contract, which will receive remaining gas after execution burn.
     * @param callbackTo Address of contract, which implement {IAcceptTokensBurnCallback.onAcceptTokensBurn}
     *        if it equals to 0:0 then no callbacks.
     * @param payload Custom data will be delivered into {IAcceptTokensBurnCallback.onAcceptTokensBurn}.
     *
     * Preconditions:
     *  - Burning by the token root must be enabled.
     *  - `walletOwner` must be a non-zero address.
     *  - `amount` must be greater than zero.
     *
     * Postconditions:
     *  - `totalSupply_` must decrease by the `amount` that is burned.
     *  - `balance_` of WalletOwner must decrease by the `amount` that is burned.
     */
    function burnTokens(
        uint128 amount,
        address walletOwner,
        address remainingGasTo,
        address callbackTo,
        TvmCell payload
    ) external;


    /**
     * @notice Allows to disable `burnTokens` method forever
     * @dev Can be called only by rootOwner
     *
     * Precondition:
     *  - sender must be rootOwner.
     *
     * Postcondition:
     *  - burn by TokenRoot must be disabled forever.
     */
    function disableBurnByRoot() external responsible returns (bool);

    /**
     * @notice Returns true if `burnTokens` method is disabled.
     */
    function burnByRootDisabled() external view responsible returns (bool);
}
