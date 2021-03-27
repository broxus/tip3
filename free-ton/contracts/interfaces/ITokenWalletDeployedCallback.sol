pragma ton-solidity ^0.38.2;

interface ITokenWalletDeployedCallback {
    function notifyWalletDeployed(address root) external;
}
