pragma solidity >= 0.6.0;
pragma AbiHeader time;
pragma AbiHeader expire;

import "./interfaces/ITONTokenWallet.sol";
import "./interfaces/IBurnableByOwnerTokenWallet.sol";
import "./interfaces/IBurnableByRootTokenWallet.sol";
import "./interfaces/IBurnableTokenRootContract.sol";

contract TONTokenWallet is ITONTokenWallet, IBurnableByOwnerTokenWallet, IBurnableByRootTokenWallet {

    bytes static name_;
    bytes static symbol_;
    uint8 static decimals_;
    address static root_address_;
    TvmCell static code_;
    //for external owner
    uint256 static wallet_public_key_;
    //for internal owner
    address static owner_address_;

    uint128 balance_;
    optional(AllowanceInfo) allowance_;

    uint8 error_message_sender_is_not_my_owner    = 100;
    uint8 error_not_enough_balance                = 101;
    uint8 error_message_sender_is_not_my_root     = 102;
    uint8 error_message_sender_is_not_good_wallet = 103;
    uint8 error_wrong_bounced_header              = 104;
    uint8 error_wrong_bounced_args                = 105;
    uint8 error_non_zero_remaining                = 106;
    uint8 error_no_allowance_set                  = 107;
    uint8 error_wrong_spender                     = 108;
    uint8 error_not_enough_allowance              = 109;
    uint8 error_low_message_value                 = 110;

    uint128 start_balance_;

    constructor() public {
        require((wallet_public_key_ != 0 && owner_address_.value == 0) ||
        (wallet_public_key_ == 0 && owner_address_.value != 0));
        tvm.accept();
        start_balance_ = address(this).balance;
    }

    function getName() override external view returns (bytes) {
        return name_;
    }

    function getSymbol() override external view returns (bytes) {
        return symbol_;
    }

    function getDecimals() override external view returns (uint8) {
        return decimals_;
    }

    function getRootAddress() override external view returns (address) {
        return root_address_;
    }

    function getOwnerAddress() override external view returns (address) {
        return owner_address_;
    }

    function getWalletPublicKey() override external view returns (uint256) {
        return wallet_public_key_;
    }

    function getBalance() override external view returns (uint128) {
        return balance_;
    }

    function allowance() override external view returns (AllowanceInfo) {
        return allowance_.hasValue() ? allowance_.get() : AllowanceInfo(0, address.makeAddrStd(0, 0));
    }

    function getDetails() override external view returns (ITONTokenWalletDetails){
        return ITONTokenWalletDetails(
            name_,
            symbol_,
            decimals_,
            root_address_,
            code_,
            wallet_public_key_,
            owner_address_,
            balance_
        );
    }

    function accept(uint128 tokens) override external onlyRoot {
        tvm.accept();
        balance_ += tokens;
    }

    function approve(address spender, uint128 remaining_tokens, uint128 tokens) override external onlyOwner {
        tvm.accept();
        if (allowance_.hasValue()) {
            if (allowance_.get().remaining_tokens == remaining_tokens) {
                allowance_.set(AllowanceInfo(tokens, spender));
            }
        } else {
            require(remaining_tokens == 0, error_non_zero_remaining);
            allowance_.set(AllowanceInfo(tokens, spender));
        }
    }

    function disapprove() override external onlyOwner {
        tvm.accept();
        allowance_.reset();
    }

    function transfer(address to, uint128 tokens, uint128 grams) override external onlyOwner {
        require(tokens <= balance_, error_not_enough_balance);
        require(to.value != 0);
        require((owner_address_.value != 0 && msg.value > 0) ||
                (owner_address_.value == 0 && grams <= address(this).balance && grams > 0), error_low_message_value);

        tvm.accept();

        balance_ -= tokens;

        if (owner_address_.value != 0 ) {
            tvm.rawReserve(math.max(start_balance_, address(this).balance - msg.value), 2); //RESERVE_UP_TO
            ITONTokenWallet(to).internalTransfer{ value: 0, flag: 128, bounce: true }(tokens, wallet_public_key_, owner_address_, owner_address_);
        } else {
            ITONTokenWallet(to).internalTransfer{value: grams, bounce: true}(tokens, wallet_public_key_, owner_address_, address(this));
        }
    }

    function transferFrom(address from, address to, uint128 tokens, uint128 grams) override external onlyOwner {
        require(to.value != 0);
        require((owner_address_.value != 0 && msg.value > 0) ||
                (owner_address_.value == 0 && grams <= address(this).balance && grams > 0), error_low_message_value);
        tvm.accept();

        if (owner_address_.value != 0 ) {
            tvm.rawReserve(math.max(start_balance_, address(this).balance - msg.value), 2); //RESERVE_UP_TO
            ITONTokenWallet(from).internalTransferFrom{ value: 0, flag: 128 }(to, tokens, owner_address_);
        } else {
            ITONTokenWallet(from).internalTransferFrom{value: grams}(to, tokens, address(this));
        }
    }

    function internalTransfer(uint128 tokens, uint256 sender_public_key, address sender_address, address send_gas_to) override external {

        address expectedSenderAddress = getExpectedAddress(sender_public_key, sender_address);

        require(msg.sender == expectedSenderAddress, error_message_sender_is_not_good_wallet);

        balance_ += tokens;

        send_gas_to.transfer({ value: 0, flag: 64 });
    }

    function internalTransferFrom(address to, uint128 tokens, address send_gas_to) override external {
        require(allowance_.hasValue(), error_no_allowance_set);
        require(msg.sender == allowance_.get().spender, error_wrong_spender);
        require(tokens <= allowance_.get().remaining_tokens, error_not_enough_allowance);
        require(tokens <= balance_, error_not_enough_balance);

        balance_ -= tokens;

        allowance_.set(AllowanceInfo(allowance_.get().remaining_tokens - tokens, allowance_.get().spender));

        ITONTokenWallet(to).internalTransfer{value: 0, bounce: true, flag: 64}(
            tokens,
            wallet_public_key_,
            owner_address_,
            send_gas_to
        );
    }

    function burnByOwner(
        uint128 tokens,
        uint128 grams,
        address callback_address,
        TvmCell callback_payload
    ) override external onlyOwner {
        require(tokens <= balance_, error_not_enough_balance);
        require((owner_address_.value != 0 && msg.value > 0) ||
                (owner_address_.value == 0 && grams <= address(this).balance && grams > 0), error_low_message_value);
        tvm.accept();

        balance_ -= tokens;

        if (owner_address_.value != 0 ) {
            tvm.rawReserve(math.max(start_balance_, address(this).balance - msg.value), 2); //RESERVE_UP_TO
            IBurnableTokenRootContract(root_address_)
                .tokensBurned{ value: 0, flag: 128 }(
                    tokens,
                    wallet_public_key_,
                    owner_address_,
                    callback_address,
                    callback_payload
                );
        } else {
            IBurnableTokenRootContract(root_address_)
                .tokensBurned{value: grams}(
                    tokens,
                    wallet_public_key_,
                    owner_address_,
                    callback_address,
                    callback_payload
                );
        }
    }

    function burnByRoot(
        uint128 tokens,
        address callback_address,
        TvmCell callback_payload
    ) override external onlyRoot {
        require(tokens <= balance_, error_not_enough_balance);
        tvm.accept();

        balance_ -= tokens;

        IBurnableTokenRootContract(root_address_)
            .tokensBurned{value: 0, flag: 64}(
                tokens,
                wallet_public_key_,
                owner_address_,
                callback_address,
                callback_payload
            );
    }

    function destroy(address gas_dest) public onlyOwner {
        require(balance_ == 0);
        selfdestruct(gas_dest);
    }

    // =============== Support functions ==================

    modifier onlyRoot() {
        require(isRoot(), error_message_sender_is_not_my_root);
        _;
    }

    modifier onlyOwner() {
        require(isOwner(), error_message_sender_is_not_my_owner);
        _;
    }

    modifier onlyInternalOwner() {
        require(isInternalOwner());
        _;
    }

    function isRoot() private inline view returns (bool) {
        return root_address_ == msg.sender;
    }

    function isOwner() private inline view returns (bool) {
        return isInternalOwner() || isExternalOwner();
    }

    function isInternalOwner() private inline view returns (bool) {
        return owner_address_.value != 0 && owner_address_ == msg.sender;
    }

    function isExternalOwner() private inline view returns (bool) {
        return wallet_public_key_ != 0 && wallet_public_key_ == tvm.pubkey();
    }

    function getExpectedAddress(uint256 wallet_public_key, address owner_address) private inline view returns (address)  {

        TvmCell stateInit = tvm.buildStateInit({
            contr: TONTokenWallet,
            varInit: {
                name_: name_,
                symbol_: symbol_,
                decimals_: decimals_,
                root_address_: root_address_,
                code_: code_,
                wallet_public_key_: wallet_public_key,
                owner_address_: owner_address
            },
            pubkey: wallet_public_key,
            code: code_
        });

        return address(tvm.hash(stateInit));
    }

    uint128 latest_bounced_tokens;

    onBounce(TvmSlice body) external {
        tvm.accept();
        uint32 functionId = body.decode(uint32);
        if (functionId == tvm.functionId(ITONTokenWallet.internalTransfer)) {
            latest_bounced_tokens = body.decode(uint128);
            balance_ += latest_bounced_tokens;
        }
    }

    fallback() external {
    }
}
