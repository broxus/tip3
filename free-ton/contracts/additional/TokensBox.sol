pragma solidity >= 0.6.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../interfaces/ITokensReceivedCallback.sol";
import "../interfaces/IDestroyable.sol";
import "../interfaces/ITONTokenWallet.sol";
import '../interfaces/IRootTokenContract.sol';
import "../interfaces/IExpectedWalletAddressCallback.sol";

/*
    Special contract, which can safe tokens and gas for `target` address.
    Withdraw: transfer any tokens amount to `wallet` from `target` wallet or wallet owned by `target`,
              with enabled option `notify_receiver`.

    // Withdraw example:
    // `target` is TONTokenWallet address in this example, but you can send it from TONTokenWallet owned by `target`
    TvmBuilder b;
    ITONTokenWallet(target){value: 0.1 ton}.transfer(
        wallet,             // to - set as `wallet` variable of this contract
        1,                  // amount - set 1 for smallest amount = 10^(-decimals)
        0,                  // grams - set it to `0.1 ton` instead {value: 0.1 ton} when wallet owned by public key
        address(this),      // gas destination
        true,               // notify_receiver (!) required TRUE
        b.toCell()          // payload - set empty payload, it will ignored
    );
*/

contract TokensBox is ITokensReceivedCallback, IExpectedWalletAddressCallback {

    address public static creator;
    address public static root;
    address public static target;

    address public wallet;

    constructor() public {
        tvm.accept();
        IRootTokenContract(root).sendExpectedWalletAddress{value: 0.05 ton}(0, address(this), address(this));
    }

    function expectedWalletAddressCallback(
        address wallet_,
        uint256 wallet_public_key,
        address owner_address
    ) override external {
        require(msg.sender == root && wallet.value == 0);
        require(wallet_public_key == 0);
        require(owner_address == address(this));

        wallet = wallet_;
        ITONTokenWallet(wallet).setReceiveCallback(address(this));
    }

    function tokensReceivedCallback(
        address token_wallet,
        address /* token_root */,
        uint128 /* tokens_amount */,
        uint256 /* sender_public_key */,
        address sender_address,
        address sender_wallet,
        address original_gas_to,
        uint128 updated_balance,
        TvmCell /* payload */
    ) override external {
        if (token_wallet == wallet && msg.sender == wallet) {
            if (sender_wallet == target || sender_address == target) {
                TvmBuilder b;
                ITONTokenWallet(wallet).transfer{ value: 0.2 ton }(
                    sender_wallet,
                    updated_balance,
                    0,
                    original_gas_to,
                    false,
                    b.toCell()
                );
                IDestroyable(wallet).destroy(original_gas_to);
                selfdestruct(original_gas_to);
            }
        }
    }

    fallback() external {
    }
}
