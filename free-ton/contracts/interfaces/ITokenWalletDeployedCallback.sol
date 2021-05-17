pragma ton-solidity ^0.43.0;

interface ITokenWalletDeployedCallback {
    function notifyWalletDeployed(address root) external;
}
