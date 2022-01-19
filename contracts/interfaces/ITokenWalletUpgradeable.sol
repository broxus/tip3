pragma ton-solidity >= 0.39.0;

import "./ITokenWallet.sol";


interface ITokenWalletUpgradeable is ITokenWallet {
    function platformCode() external view responsible returns (TvmCell);
    function upgrade(address remainingGasTo) external;
    function upgradeInternal(TvmCell code, uint32 newVersion, address remainingGasTo) external;
}
