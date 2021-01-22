pragma solidity >= 0.6.0;

pragma AbiHeader time;
pragma AbiHeader expire;

import "../interfaces/ITokensBurner.sol";
import "../interfaces/IRootTokenContract.sol";
import "../interfaces/ITONTokenWallet.sol";

contract TONTokenWalletInternalOwnerTest {

    uint256 static _randomNonce;

    uint256 static external_owner_pubkey_;

    uint8 error_message_sender_is_not_my_owner = 100;

    constructor() public {
        tvm.accept();
    }

    function burnMyTokens(
        uint128 tokens,
        uint128 grams,
        address burner_address,
        address callback_address,
        bytes ethereum_address
    ) external view onlyExternalOwner {
        require(ethereum_address.length  == 20);

        tvm.accept();

        TvmBuilder builder;
        builder.store(ethereum_address);
        TvmCell callback_payload = builder.toCell();

        ITokensBurner(burner_address).burnMyTokens{value: grams}(tokens, callback_address, callback_payload);
    }

    function testTransferFrom(uint128 tokens, uint128 grams, address from, address to, address wallet) external view onlyExternalOwner {
        tvm.accept();
        ITONTokenWallet(wallet).transferFrom{value: grams}(from, to, tokens, 0);
    }

    function deployEmptyWallet(address root_address, uint128 grams) external view onlyExternalOwner {
        tvm.accept();
        IRootTokenContract(root_address).deployEmptyWallet{value: grams}(
            0.1 ton,
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
    )
        public
        view
        onlyExternalOwner
    {
        tvm.accept();
        dest.transfer(value, bounce, flags, payload);
    }

    modifier onlyExternalOwner() {
        require(isExternalOwner(), error_message_sender_is_not_my_owner);
        _;
    }

    function isExternalOwner() private inline view returns (bool) {
        return external_owner_pubkey_ != 0 && external_owner_pubkey_ == tvm.pubkey();
    }
}
