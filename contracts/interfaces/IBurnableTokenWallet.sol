pragma ton-solidity >= 0.39.0;

/*

walletOwner -> IBurnableTokenWallet(wallet).burn(...) ->
               IBurnableTokenRoot(root).tokensBurned(...) ->
               IAcceptTokensBurnCallback(callbackTo).onAcceptTokensBurn(...) -> ...
*/


interface IBurnableTokenWallet {

    /*
        @notice Allows for walletOwner burn tokens
        @dev Can be called only by TokenWallet owner
        @param amount Amount tokens to burn
        @param remainingGasTo Receiver of the remaining EVERs
        @param callbackTo Address of contract, which implement IAcceptTokensBurnCallback.onAcceptTokensBurn
               if it equals to 0:0 then no callbacks
        @param payload Custom data will be delivered into IAcceptTokensBurnCallback.onAcceptTokensBurn
    */
    function burn(
        uint128 amount,
        address remainingGasTo,
        address callbackTo,
        TvmCell payload
    ) external;
}
