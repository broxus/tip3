pragma ton-solidity >= 0.39.0;

interface ITokenWalletDeployedCallback {
    function notifyWalletDeployed(address root) external;
}
