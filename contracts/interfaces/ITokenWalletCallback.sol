pragma ton-solidity >= 0.39.0;

/*
    Callbacks from TokenWallet.
*/


interface ITokenWalletCallback {

    /*
        @notice Callback from TokenWallet on successful call setCallback
        @param onlyNotifiableTransfers - Wallet don't receive transfers without notify
    */
    function callbackConfigured(bool onlyNotifiableTransfers) external;

    /*
        @notice Callback from TokenWallet on receive tokens transfer
        @param tokenWallet TokenWallet for which tokens were received
        @param tokenRoot TokenRoot of received tokens
        @param amount Received tokens amount
        @param sender Sender TokenWallet owner address
        @param senderWallet Sender TokenWallet address
        @param remainingGasTo Address specified for receive remaining gas
        @param payload Additional data attached to transfer by sender
    */
    function onTokenTransferReceived(
        address tokenWallet,
        address tokenRoot,
        uint128 amount,
        address sender,
        address senderWallet,
        address remainingGasTo,
        TvmCell payload
    ) external;

    /*
        @notice Callback from TokenWallet when tokens transfer reverted
        @param tokenWallet TokenWallet for which tokens were received
        @param tokenRoot TokenRoot of received tokens
        @param amount Reverted tokens amount
        @param revertedFrom Address which declained internalTransfer
    */
    function onTokenTransferReverted(
        address tokenWallet,
        address tokenRoot,
        uint128 amount,
        address revertedFrom
    ) external;


}
