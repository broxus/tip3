pragma ton-solidity >= 0.39.0;

import "./ITokenRoot.sol";


interface ITokenRootUpgradeable is ITokenRoot {
    function requestUpgradeWallet(uint32 currentVersion, address walletOwner, address remainingGasTo) external;
    function setWalletCode(TvmCell code) external;
    function walletVersion() external view responsible returns (uint32);
    function platformCode() external view responsible returns (TvmCell);
    function upgrade(TvmCell code) external;
}
