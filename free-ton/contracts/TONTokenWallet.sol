pragma solidity >= 0.6.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/IDestroyable.sol";
import "./interfaces/ITONTokenWallet.sol";
import "./interfaces/IBurnableByOwnerTokenWallet.sol";
import "./interfaces/IBurnableByRootTokenWallet.sol";
import "./interfaces/IBurnableTokenRootContract.sol";
import "./interfaces/ITokenWalletDeployedCallback.sol";
import "./interfaces/ITokensReceivedCallback.sol";
import "./interfaces/ITokensBouncedCallback.sol";

contract TONTokenWallet is ITONTokenWallet, IDestroyable, IBurnableByOwnerTokenWallet, IBurnableByRootTokenWallet {

    address static root_address;
    TvmCell static code;
    //for external owner
    uint256 static wallet_public_key;
    //for internal owner
    address static owner_address;

    uint128 target_gas_balance                            = 0.05 ton;

    uint128 public balance;
    optional(AllowanceInfo) allowance_;

    uint8 error_message_sender_is_not_my_owner            = 100;
    uint8 error_not_enough_balance                        = 101;
    uint8 error_message_sender_is_not_my_root             = 102;
    uint8 error_message_sender_is_not_good_wallet         = 103;
    uint8 error_wrong_bounced_header                      = 104;
    uint8 error_wrong_bounced_args                        = 105;
    uint8 error_non_zero_remaining                        = 106;
    uint8 error_no_allowance_set                          = 107;
    uint8 error_wrong_spender                             = 108;
    uint8 error_not_enough_allowance                      = 109;
    uint8 error_low_message_value                         = 110;
    uint8 error_define_wallet_public_key_or_owner_address = 111;
    uint8 error_wrong_recipient                           = 112;
    uint8 error_recipient_has_disallow_non_notifiable     = 113;

    address receive_callback;
    address bounced_callback;
    bool allow_non_notifiable = true;

    constructor() public {
        require((wallet_public_key != 0 && owner_address.value == 0) ||
                (wallet_public_key == 0 && owner_address.value != 0));
        tvm.accept();
        if (owner_address.value != 0) {
            ITokenWalletDeployedCallback(owner_address).notifyWalletDeployed{value: 0.00001 ton}(root_address);
        }
    }

    function getDetails() override external view returns (ITONTokenWalletDetails){
        return ITONTokenWalletDetails(
            root_address,
            code,
            wallet_public_key,
            owner_address,
            balance,
            receive_callback,
            bounced_callback,
            allow_non_notifiable
        );
    }

    function accept(uint128 tokens) override external onlyRoot {
        balance += tokens;
    }

    function allowance() override external view returns (AllowanceInfo) {
        return allowance_.hasValue() ? allowance_.get() : AllowanceInfo(0, address.makeAddrStd(0, 0));
    }

    function approve(address spender, uint128 remaining_tokens, uint128 tokens) override external onlyOwner {
        require(remaining_tokens == 0 || !allowance_.hasValue(), error_non_zero_remaining);
        if (owner_address.value != 0 ) {
            tvm.rawReserve(math.max(target_gas_balance, address(this).balance - msg.value), 2);
        } else {
            tvm.accept();
        }

        if (allowance_.hasValue()) {
            if (allowance_.get().remaining_tokens == remaining_tokens) {
                allowance_.set(AllowanceInfo(tokens, spender));
            }
        } else {
            allowance_.set(AllowanceInfo(tokens, spender));
        }

        if (owner_address.value != 0 ) {
            msg.sender.transfer({ value: 0, flag: 128 });
        }
    }

    function disapprove() override external onlyOwner {
        if (owner_address.value != 0 ) {
            tvm.rawReserve(math.max(target_gas_balance, address(this).balance - msg.value), 2);
        } else {
            tvm.accept();
        }

        allowance_.reset();

        if (owner_address.value != 0 ) {
            msg.sender.transfer({ value: 0, flag: 128 });
        }
    }

    function transferToRecipient(
        uint256 recipient_public_key,
        address recipient_address,
        uint128 tokens,
        uint128 deploy_grams,
        uint128 transfer_grams,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    ) override external onlyOwner {
        require(tokens > 0);
        require(tokens <= balance, error_not_enough_balance);
        require((recipient_address.value != 0 && recipient_public_key == 0) ||
                (recipient_address.value == 0 && recipient_public_key != 0),
                error_define_wallet_public_key_or_owner_address);

        if (owner_address.value != 0 ) {
            uint128 reserve = math.max(target_gas_balance, address(this).balance - msg.value);
            require(address(this).balance > reserve + target_gas_balance + deploy_grams, error_low_message_value);
            require(recipient_address != owner_address, error_wrong_recipient);
            tvm.rawReserve(reserve, 2);
        } else {
            require(address(this).balance > deploy_grams + transfer_grams, error_low_message_value);
            require(transfer_grams > target_gas_balance, error_low_message_value);
            require(recipient_public_key != wallet_public_key);
            tvm.accept();
        }

        TvmCell stateInit = tvm.buildStateInit({
            contr: TONTokenWallet,
            varInit: {
                root_address: root_address,
                code: code,
                wallet_public_key: recipient_public_key,
                owner_address: recipient_address
            },
            pubkey: recipient_public_key,
            code: code
        });

        address to = address(tvm.hash(stateInit));

        if(deploy_grams > 0) {
            tvm.deploy(stateInit, tvm.encodeBody(TONTokenWallet), deploy_grams, address(this).wid);
        }

        address send_gas_to_ = send_gas_to;

        if (owner_address.value != 0 ) {
            balance -= tokens;
            if (send_gas_to_.value == 0) {
                send_gas_to_ = owner_address;
            }
            ITONTokenWallet(to).internalTransfer{ value: 0, flag: 128, bounce: true }(
                tokens,
                wallet_public_key,
                owner_address,
                send_gas_to_,
                notify_receiver,
                payload
            );
        } else {
            balance -= tokens;
            if (send_gas_to_.value == 0) {
                send_gas_to_ = address(this);
            }
            ITONTokenWallet(to).internalTransfer{ value: transfer_grams, bounce: true }(
                tokens,
                wallet_public_key,
                owner_address,
                send_gas_to_,
                notify_receiver,
                payload
            );
        }
    }

    function transfer(
        address to,
        uint128 tokens,
        uint128 grams,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    ) override external onlyOwner {
        require(tokens > 0);
        require(tokens <= balance, error_not_enough_balance);
        require(to.value != 0, error_wrong_recipient);
        require(to != address(this), error_wrong_recipient);

        if (owner_address.value != 0 ) {
            uint128 reserve = math.max(target_gas_balance, address(this).balance - msg.value);
            require(address(this).balance > reserve + target_gas_balance, error_low_message_value);
            tvm.rawReserve(reserve, 2);
            balance -= tokens;

            address send_gas_to_ = send_gas_to;
            if (send_gas_to_.value == 0) {
                send_gas_to_ = owner_address;
            }
            ITONTokenWallet(to).internalTransfer{ value: 0, flag: 128, bounce: true }(
                tokens,
                wallet_public_key,
                owner_address,
                send_gas_to_,
                notify_receiver,
                payload
            );
        } else {
            require(address(this).balance > grams, error_low_message_value);
            require(grams > target_gas_balance, error_low_message_value);
            tvm.accept();
            balance -= tokens;

            address send_gas_to_ = send_gas_to;
            if (send_gas_to_.value == 0) {
                send_gas_to_ = address(this);
            }
            ITONTokenWallet(to).internalTransfer{ value: grams, bounce: true }(
                tokens,
                wallet_public_key,
                owner_address,
                send_gas_to_,
                notify_receiver,
                payload
            );
        }
    }

    function transferFrom(
        address from,
        address to,
        uint128 tokens,
        uint128 grams,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    ) override external onlyOwner {
        require(to.value != 0, error_wrong_recipient);
        require(tokens > 0);
        require(from != to, error_wrong_recipient);

        address send_gas_to_ = send_gas_to;

        if (owner_address.value != 0 ) {
            uint128 reserve = math.max(target_gas_balance, address(this).balance - msg.value);
            require(address(this).balance > reserve + (target_gas_balance * 2), error_low_message_value);
            tvm.rawReserve(reserve, 2);
            if (send_gas_to_.value == 0) {
                send_gas_to_ = owner_address;
            }
            ITONTokenWallet(from).internalTransferFrom{ value: 0, flag: 128 }(
                to,
                tokens,
                send_gas_to_,
                notify_receiver,
                payload
            );
        } else {
            require(address(this).balance > grams, error_low_message_value);
            require(grams > target_gas_balance * 2, error_low_message_value);
            tvm.accept();
            if (send_gas_to_.value == 0) {
                send_gas_to_ = address(this);
            }
            ITONTokenWallet(from).internalTransferFrom{ value: grams }(
                to,
                tokens,
                send_gas_to_,
                notify_receiver,
                payload
            );
        }
    }

    function internalTransfer(
        uint128 tokens,
        uint256 sender_public_key,
        address sender_address,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    ) override external {
        require(notify_receiver || allow_non_notifiable || receive_callback.value == 0,
                error_recipient_has_disallow_non_notifiable);
        address expectedSenderAddress = getExpectedAddress(sender_public_key, sender_address);
        require(msg.sender == expectedSenderAddress, error_message_sender_is_not_good_wallet);
        require(sender_address != owner_address || sender_public_key != wallet_public_key, error_wrong_recipient);

        if (owner_address.value != 0 ) {
            uint128 reserve = math.max(target_gas_balance, address(this).balance - msg.value);
            require(address(this).balance > reserve, error_low_message_value);
            tvm.rawReserve(reserve, 2);
        } else {
            tvm.rawReserve(address(this).balance - msg.value, 2);
        }

        balance += tokens;

        if (notify_receiver && receive_callback.value != 0) {
            ITokensReceivedCallback(receive_callback).tokensReceivedCallback{ value: 0, flag: 128 }(
                address(this),
                root_address,
                tokens,
                sender_public_key,
                sender_address,
                msg.sender,
                send_gas_to,
                balance,
                payload
            );
        } else {
            send_gas_to.transfer({ value: 0, flag: 128 });
        }
    }

    function internalTransferFrom(
        address to,
        uint128 tokens,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    ) override external {
        require(allowance_.hasValue(), error_no_allowance_set);
        require(msg.sender == allowance_.get().spender, error_wrong_spender);
        require(tokens <= allowance_.get().remaining_tokens, error_not_enough_allowance);
        require(tokens <= balance, error_not_enough_balance);
        require(tokens > 0);
        require(to != address(this), error_wrong_recipient);

        if (owner_address.value != 0 ) {
            uint128 reserve = math.max(target_gas_balance, address(this).balance - msg.value);
            require(address(this).balance > reserve + target_gas_balance, error_low_message_value);
            tvm.rawReserve(reserve, 2);
            tvm.rawReserve(math.max(target_gas_balance, address(this).balance - msg.value), 2);
        } else {
            require(msg.value > target_gas_balance, error_low_message_value);
            tvm.rawReserve(address(this).balance - msg.value, 2);
        }

        balance -= tokens;

        allowance_.set(AllowanceInfo(allowance_.get().remaining_tokens - tokens, allowance_.get().spender));

        ITONTokenWallet(to).internalTransfer{ value: 0, bounce: true, flag: 128 }(
            tokens,
            wallet_public_key,
            owner_address,
            send_gas_to,
            notify_receiver,
            payload
        );
    }

    function burnByOwner(
        uint128 tokens,
        uint128 grams,
        address send_gas_to,
        address callback_address,
        TvmCell callback_payload
    ) override external onlyOwner {
        require(tokens > 0);
        require(tokens <= balance, error_not_enough_balance);
        require((owner_address.value != 0 && msg.value > 0) ||
                (owner_address.value == 0 && grams <= address(this).balance && grams > 0), error_low_message_value);

        address send_gas_to_ = send_gas_to;

        if (owner_address.value != 0 ) {
            tvm.rawReserve(math.max(target_gas_balance, address(this).balance - msg.value), 2);
            balance -= tokens;
            if (send_gas_to_.value == 0) {
                send_gas_to_ = owner_address;
            }
            IBurnableTokenRootContract(root_address)
                .tokensBurned{ value: 0, flag: 128, bounce: true }(
                    tokens,
                    wallet_public_key,
                    owner_address,
                    send_gas_to_,
                    callback_address,
                    callback_payload
                );
        } else {
            tvm.accept();
            balance -= tokens;
            if (send_gas_to_.value == 0) {
                send_gas_to_ = address(this);
            }
            IBurnableTokenRootContract(root_address)
                .tokensBurned{ value: grams, bounce: true }(
                    tokens,
                    wallet_public_key,
                    owner_address,
                    send_gas_to_,
                    callback_address,
                    callback_payload
                );
        }
    }

    function burnByRoot(
        uint128 tokens,
        address send_gas_to,
        address callback_address,
        TvmCell callback_payload
    ) override external onlyRoot {
        require(tokens > 0);
        require(tokens <= balance, error_not_enough_balance);

        tvm.rawReserve(address(this).balance - msg.value, 2);

        balance -= tokens;

        IBurnableTokenRootContract(root_address)
            .tokensBurned{ value: 0, flag: 128, bounce: true }(
                tokens,
                wallet_public_key,
                owner_address,
                send_gas_to,
                callback_address,
                callback_payload
            );
    }

    function setReceiveCallback(address receive_callback_, bool allow_non_notifiable_) override external onlyOwner {
        tvm.accept();
        receive_callback = receive_callback_;
        allow_non_notifiable = allow_non_notifiable_;
    }

    function setBouncedCallback(address bounced_callback_) override external onlyOwner {
        tvm.accept();
        bounced_callback = bounced_callback_;
    }

    function destroy(address gas_dest) override public onlyOwner {
        require(balance == 0);
        tvm.accept();
        selfdestruct(gas_dest);
    }

    // =============== Support functions ==================

    modifier onlyRoot() {
        require(root_address == msg.sender, error_message_sender_is_not_my_root);
        _;
    }

    modifier onlyOwner() {
        require((owner_address.value != 0 && owner_address == msg.sender) ||
                (wallet_public_key != 0 && wallet_public_key == msg.pubkey()),
                error_message_sender_is_not_my_owner);
        _;
    }

    modifier onlyInternalOwner() {
        require(owner_address.value != 0 && owner_address == msg.sender);
        _;
    }

    function getExpectedAddress(uint256 wallet_public_key_, address owner_address_) private inline view returns (address)  {

        TvmCell stateInit = tvm.buildStateInit({
            contr: TONTokenWallet,
            varInit: {
                root_address: root_address,
                code: code,
                wallet_public_key: wallet_public_key_,
                owner_address: owner_address_
            },
            pubkey: wallet_public_key_,
            code: code
        });

        return address(tvm.hash(stateInit));
    }

    onBounce(TvmSlice body) external {
        tvm.accept();
        uint32 functionId = body.decode(uint32);
        if (functionId == tvm.functionId(ITONTokenWallet.internalTransfer)) {
            uint128 tokens = body.decode(uint128);
            balance += tokens;
            if (bounced_callback.value != 0) {
                tvm.rawReserve(address(this).balance - msg.value, 2);
                ITokensBouncedCallback(bounced_callback).tokensBouncedCallback{ value: 0, flag: 128 }(
                    address(this),
                    root_address,
                    tokens,
                    msg.sender,
                    balance
                );
            } else if (owner_address.value != 0) {
                tvm.rawReserve(math.max(target_gas_balance, address(this).balance - msg.value), 2);
                owner_address.transfer({ value: 0, flag: 128 });
            }   
        } else if (functionId == tvm.functionId(IBurnableTokenRootContract.tokensBurned)) {
            balance += body.decode(uint128);
            if (owner_address.value != 0) {
                tvm.rawReserve(math.max(target_gas_balance, address(this).balance - msg.value), 2);
                owner_address.transfer({ value: 0, flag: 128 });
            }
        }
    }

    fallback() external {
    }
}
