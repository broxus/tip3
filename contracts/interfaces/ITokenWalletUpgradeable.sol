pragma ton-solidity >= 0.39.0;

import "./ITokenWallet.sol";


interface ITokenWalletUpgradeable is ITokenWallet {
    function requestUpgrade(address callbackTo) external;
    function upgrade(TvmCell code, uint32 newVersion, address callbackTo) external;
}
