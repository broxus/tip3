pragma solidity >= 0.6.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../interfaces/ITokensBurner.sol";
import "../interfaces/IRootTokenContract.sol";
import "../interfaces/ITONTokenWallet.sol";
import "../interfaces/ITokensReceivedCallback.sol";

contract TONTokenWalletInternalOwnerTest is ITokensReceivedCallback {

    uint256 static _randomNonce;

    uint256 static external_owner_pubkey_;

    uint8 error_message_sender_is_not_my_owner = 100;

    constructor() public {
        tvm.accept();
    }

    mapping(address => address) change_directions;

    function tokensReceivedCallback(
        address token_wallet,
        address,
        uint128 amount,
        uint256 sender_public_key,
        address sender_address,
        address,
        address original_gas_to,
        uint128,
        TvmCell
    ) override external {
        require(change_directions.exists(token_wallet));
        tvm.rawReserve(address(this).balance - msg.value, 2);
        TvmBuilder b;
        ITONTokenWallet(change_directions.at(token_wallet))
            .transferToRecipient{value: 0.25 ton}(sender_public_key, sender_address, amount, 0.05 ton, 0, original_gas_to, false, b.toCell());
    }

    function subscribeForTransfers(address wallet1, address wallet2) external onlyExternalOwner {
        tvm.accept();
        change_directions[wallet1] = wallet2;
        change_directions[wallet2] = wallet1;
        ITONTokenWallet(wallet1).setReceiveCallback(address(this));
        ITONTokenWallet(wallet2).setReceiveCallback(address(this));
    }

    function burnMyTokens(
        uint128 tokens,
        uint128 grams,
        address burner_address,
        address callback_address,
        uint160 ethereum_address
    ) external view onlyExternalOwner {
        require(ethereum_address  != 0);

        tvm.accept();

        TvmBuilder builder;
        builder.store(ethereum_address);
        TvmCell callback_payload = builder.toCell();

        ITokensBurner(burner_address).burnMyTokens{value: grams}(tokens, callback_address, callback_payload);
    }

    function testTransferFrom(uint128 tokens, uint128 grams, address from, address to, address wallet) external view onlyExternalOwner {
        tvm.accept();
        TvmBuilder b;
        ITONTokenWallet(wallet).transferFrom{value: grams}(from, to, tokens, 0, address(this), true, b.toCell());
    }

    function deployEmptyWallet(address root_address, uint128 grams) external view onlyExternalOwner {
        tvm.accept();
        IRootTokenContract(root_address).deployEmptyWallet{value: 1 ton}(
            grams,
            0,
            address(this),
            address.makeAddrStd(0, 0)
        );
    }

    function sendTransaction(
        address dest,
        uint128 value,
        bool bounce,
        uint8 flags,
        TvmCell payload
    ) public view onlyExternalOwner {
        tvm.accept();
        dest.transfer(value, bounce, flags, payload);
    }

    modifier onlyExternalOwner() {
        require(isExternalOwner(), error_message_sender_is_not_my_owner);
        _;
    }

    function isExternalOwner() private inline view returns (bool) {
        return external_owner_pubkey_ != 0 && external_owner_pubkey_ == msg.pubkey();
    }
}
