pragma ton-solidity >= 0.57.0;

/**
 * @notice Callback interface for handling a reverted token transfer, according to
 * the TIP-3.2 standard.
 *
 *  walletOwner  -> ITokenWallet(walletOwner).transfer(...) ->
 *                  ITokenWallet(receiver).acceptTransfer(...) ->
 *                  TokenWalletBase.onBounce(...) ->
 *                  IBounceTokensTransferCallback(callbackTo).onBounceTokensTransfer(...) ->
 */
interface IBounceTokensTransferCallback {

    /**
     * @notice Invoked by the token wallet when a transfer operation is reverted.
     * @param tokenRoot TokenRoot of token wallet.
     * @param amount Reverted tokens amount.
     * @param revertedFrom Address of the wallet that rejected the transfer.
     *
     * Note: This callback function has no implementation in the main contracts.
     * However, you can see an example of its implementation in the test contract.
     * See {TestWalletCallback.onBounceTokensTransfer}.
    */
    function onBounceTokensTransfer(
        address tokenRoot,
        uint128 amount,
        address revertedFrom
    ) external;
}
