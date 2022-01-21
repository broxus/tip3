pragma ton-solidity >= 0.39.0;


interface IRevertTokensTransferCallback {

    /*
        @notice Callback from TokenWallet when tokens transfer reverted
        @param tokenWallet TokenWallet for which tokens were received
        @param tokenRoot TokenRoot of received tokens
        @param amount Reverted tokens amount
        @param revertedFrom Address which declained acceptTransfer
    */
    function onRevertTokensTransfer(
        address tokenRoot,
        uint128 amount,
        address revertedFrom
    ) external;


}
