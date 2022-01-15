pragma ton-solidity >= 0.39.0;


interface IAcceptMintedTokensCallback {

    /*
        @notice Callback from TokenWallet on accept minted tokens
        @param tokenWallet TokenWallet received tokens
        @param tokenRoot TokenRoot of received tokens
        @param amount Minted tokens amount
        @param remainingGasTo Address specified for receive remaining gas
        @param payload Additional data attached to mint
    */
    function onAcceptMintedTokens(
        address tokenWallet,
        address tokenRoot,
        uint128 amount,
        address remainingGasTo,
        TvmCell payload
    ) external;


}
