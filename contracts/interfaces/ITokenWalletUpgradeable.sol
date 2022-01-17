pragma ton-solidity >= 0.39.0;

import "./ITokenWallet.sol";


interface ITokenWalletUpgradeable is ITokenWallet {
    function requestUpgrade(address remainingGasTo) external;
    function upgrade(TvmCell code, uint32 newVersion, address remainingGasTo) external;
}
