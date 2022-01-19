pragma ton-solidity >= 0.39.0;


interface ITokenBurnRevertedCallback {

    /*
        @notice Callback from TokenWallet on tokens burn reverted
        @param tokenRoot TokenRoot of received tokens
        @param amount Reverted tokens amount
    */
    function onTokenBurnReverted(
        address tokenRoot,
        uint128 amount
    ) external;


}
