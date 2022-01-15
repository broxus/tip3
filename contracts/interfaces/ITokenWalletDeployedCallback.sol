pragma ton-solidity >= 0.39.0;


interface ITokenWalletDeployedCallback {
    /*
        @notice Callback from TokenRoot on TokenWallet deployed
        @dev   Callback send to address specified in param 'callbackTo' in method TokenRoot.deployWallet
        @param owner Deployed TokenWallet owner
        @param wallet Deployed TokenWallet address
        @param version Deployed TokenWallet version
    */
    function onTokenWalletDeployed(address owner, address wallet, uint32 version) external;
}
