pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;

/*

walletOwner -> IBurnableTokenWallet(wallet).burn(...) ->
               IBurnableTokenRoot(root).tokensBurned(...) ->
               IBurnTokensCallback(callbackTo).burnCallback(...)
*/


interface IBurnableTokenRoot {

    /*
        @notice Called by TokenWallet, when
        @dev Decrease total supply
        @dev Can be called only by correct token wallet contract
        @dev Fails if root token burn paused
        @param amount How much tokens was burned
        @param walletOwner Burner TokenWallet owner address
        @param remainingGasTo Receiver of the remaining EVERs
        @param callbackTo address of contract, which implement IBurnTokensCallback.burnCallback
               if it equals to 0:0 then no callbacks
        @param payload Custom data will be delivered into IBurnTokensCallback.burnCallback
    */
    function tokensBurned(
        uint128 amount,
        address walletOwner,
        address remainingGasTo,
        address callbackTo,
        TvmCell payload
    ) external;

    /*
        @notice Pause/Unpause token burns
        @dev Can be called only by rootOwner
        @dev if paused, then all burned tokens will be bounced to TokenWallet
        @param paused
        @returns paused
    */
    function setBurnPaused(bool paused) external responsible returns(bool);

    /*
        @notice Get burn paused status
        @returns paused
    */
    function burnPaused() external view responsible returns(bool);
}
