pragma ton-solidity >= 0.39.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./TokenWalletDestroyableBase.sol";
import "../interfaces/ITokenRoot.sol";
import "../interfaces/IBurnableTokenWallet.sol";
import "../interfaces/IBurnPausableTokenRoot.sol";
import "../libraries/TokenErrors.sol";
import "../libraries/TokenMsgFlag.sol";


abstract contract TokenWalletBurnableBase is TokenWalletDestroyableBase, IBurnableTokenWallet {

    /*
        @notice Burn tokens
        @dev Can be called only by token wallet owner
        @param tokens How much tokens to burn
        @param grams How much EVERs attach to tokensBurned in case called with owner public key
        @param remainingGasTo Receiver of the remaining EVERs balance, used in tokensBurned callback
        @param callbackTo Address of contract, which implement IAcceptTokensBurnCallback.onAcceptTokensBurn
               if it equals to 0:0 then no callbacks
        @param payload Custom data will be delivered into IAcceptTokensBurnCallback.onAcceptTokensBurn
    */
    function burn(uint128 amount, address remainingGasTo, address callbackTo, TvmCell payload)
        override
        external
        onlyOwner
    {
        _burn(amount, remainingGasTo, callbackTo, payload, _reserve());
    }

    function _burn(
        uint128 amount,
        address remainingGasTo,
        address callbackTo,
        TvmCell payload,
        uint128 reserve
    ) internal {
        require(amount > 0, TokenErrors.WRONG_AMOUNT);
        require(amount <= balance_, TokenErrors.NOT_ENOUGH_BALANCE);

        tvm.rawReserve(reserve, 0);

        balance_ -= amount;

        ITokenRoot(root_).acceptBurn{ value: 0, flag: TokenMsgFlag.ALL_NOT_RESERVED, bounce: true }(
            amount,
            owner_,
            remainingGasTo,
            callbackTo,
            payload
        );
    }
    function _reserve() override virtual internal pure returns(uint128);
}
