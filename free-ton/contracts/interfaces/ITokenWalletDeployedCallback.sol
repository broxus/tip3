pragma solidity >= 0.6.0;

interface ITokenWalletDeployedCallback {
    function notifyWalletDeployed(address root) external;
}
