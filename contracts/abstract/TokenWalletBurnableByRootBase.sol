pragma ton-solidity >= 0.39.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./TokenWalletBurnableBase.sol";
import "../interfaces/IBurnableByRootTokenWallet.sol";


abstract contract TokenWalletBurnableByRootBase is TokenWalletBurnableBase, IBurnableByRootTokenWallet {

    /*
        @notice Allows for rootOwner burn tokens from TokenWallet
        @dev Can be called only by TokenRoot
        @param amount Amount tokens to burn
        @param remainingGasTo Receiver of the remaining EVERs
        @param callbackTo address of contract, which implement IAcceptTokensBurnCallback.onAcceptTokensBurn
               if it equals to 0:0 then no callbacks
        @param payload Custom data will be delivered into IAcceptTokensBurnCallback.onAcceptTokensBurn
    */
    function burnByRoot(uint128 amount, address remainingGasTo, address callbackTo, TvmCell payload)
        override
        external
        onlyRoot
    {
        _burn(amount, remainingGasTo, callbackTo, payload, address(this).balance - msg.value);
    }

}
