pragma solidity >= 0.6.0;
pragma AbiHeader time;
pragma AbiHeader expire;

import "./interfaces/IBurnableByRootTokenWallet.sol";
import "./interfaces/IBurnableTokenRootContract.sol";
import "./interfaces/IBurnableByRootTokenRootContract.sol";
import "./interfaces/IBurnTokensCallback.sol";
import "./interfaces/IRootTokenContract.sol";
import "./interfaces/ITONTokenWallet.sol";
import "./TONTokenWallet.sol";

contract RootTokenContract is IRootTokenContract, IBurnableTokenRootContract, IBurnableByRootTokenRootContract {

    uint256 static _randomNonce;

    bytes static name_;
    bytes static symbol_;
    uint8 static decimals_;
    TvmCell static wallet_code_;
    uint256 static root_public_key_;
    address static root_owner_address_;

    uint128 total_supply_;

    uint128 start_balance_;

    uint8 error_message_sender_is_not_my_owner = 100;
    uint8 error_not_enough_balance = 101;
    uint8 error_message_sender_is_not_good_wallet = 103;
    uint8 error_define_wallet_public_key_or_owner_address = 106;

    constructor() public {
        require(root_public_key_ != 0 && root_owner_address_.value == 0 ||
                root_public_key_ == 0 && root_owner_address_.value != 0,
                error_define_wallet_public_key_or_owner_address);
        tvm.accept();

        total_supply_ = 0;

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

    function getRootPublicKey() override external view returns (uint256) {
        return root_public_key_;
    }

    function getRootOwnerAddress() override external view returns (address) {
        return root_owner_address_;
    }

    function getTotalSupply() override external view returns (uint128) {
        return total_supply_;
    }

    function getWalletCode() override external view returns (TvmCell) {
        return wallet_code_;
    }

    function getDetails() override external view returns (IRootTokenContractDetails) {
        return IRootTokenContractDetails(
            name_,
            symbol_,
            decimals_,
            wallet_code_,
            root_public_key_,
            root_owner_address_,
            total_supply_
        );
    }

    function getWalletAddress(uint256 wallet_public_key, address owner_address) override external returns (address) {
        require(owner_address.value != 0 && wallet_public_key == 0 ||
                owner_address.value == 0 && wallet_public_key != 0,
                error_define_wallet_public_key_or_owner_address);
        address walletAddress = getExpectedWalletAddress(wallet_public_key, owner_address);
        return walletAddress;
    }

    function deployWallet(
        uint128 tokens,
        uint128 grams,
        uint256 wallet_public_key,
        address owner_address,
        address gas_back_address
    ) override external onlyOwner {
        require(tokens >= 0);
        require(owner_address.value != 0 && wallet_public_key == 0 ||
                owner_address.value == 0 && wallet_public_key != 0,
                error_define_wallet_public_key_or_owner_address);

        tvm.accept();

        if(root_owner_address_.value != 0) {
            tvm.rawReserve(math.max(start_balance_, address(this).balance - msg.value), 2); //RESERVE_UP_TO
        }

        address wallet = new TONTokenWallet{
            value: grams,
            code: wallet_code_,
            pubkey: wallet_public_key,
            varInit: {
                name_: name_,
                symbol_: symbol_,
                decimals_: decimals_,
                root_address_: address(this),
                code_: wallet_code_,
                wallet_public_key_: wallet_public_key,
                owner_address_: owner_address
            }
        }();

        ITONTokenWallet(wallet).accept(tokens);

        total_supply_ += tokens;

        if (root_owner_address_.value != 0) {
            if (gas_back_address.value != 0) {
                gas_back_address.transfer({ value: 0, flag: 128 }); //SEND_ALL_GAS
            } else {
                msg.sender.transfer({ value: 0, flag: 128 }); //SEND_ALL_GAS
            }
        }
    }

    function deployEmptyWallet(
        uint128 grams,
        uint256 wallet_public_key,
        address owner_address,
        address gas_back_address
    ) override external {
        require(owner_address.value != 0 && wallet_public_key == 0 ||
                owner_address.value == 0 && wallet_public_key != 0,
                error_define_wallet_public_key_or_owner_address);

        tvm.accept();

        tvm.rawReserve(math.max(start_balance_, address(this).balance - msg.value), 2); //RESERVE_UP_TO

        new TONTokenWallet{
            value: grams,
            code: wallet_code_,
            pubkey: wallet_public_key,
            varInit: {
                name_: name_,
                symbol_: symbol_,
                decimals_: decimals_,
                root_address_: address(this),
                code_: wallet_code_,
                wallet_public_key_: wallet_public_key,
                owner_address_: owner_address
            }
        }();

        if (gas_back_address.value != 0) {
            gas_back_address.transfer({ value: 0, flag: 128 }); //SEND_ALL_GAS
        } else {
            msg.sender.transfer({ value: 0, flag: 128 }); //SEND_ALL_GAS
        }
    }

    function mint(uint128 tokens, address to) override external onlyOwner {
        tvm.accept();

        ITONTokenWallet(to).accept(tokens);

        total_supply_ += tokens;
    }


    function proxyBurn(
        uint128 tokens,
        address sender_address,
        address callback_address,
        TvmCell callback_payload
    ) override external onlyInternalOwner {
        tvm.accept();
        address expectedWalletAddress = getExpectedWalletAddress(0, sender_address);
        IBurnableByRootTokenWallet(expectedWalletAddress).burnByRoot{value: 0, flag: 64}(
            tokens,
            callback_address,
            callback_payload
        );
    }

    function tokensBurned(
        uint128 tokens,
        uint256 sender_public_key,
        address sender_address,
        address callback_address,
        TvmCell callback_payload
    ) override external {

        address expectedWalletAddress = getExpectedWalletAddress(sender_public_key, sender_address);

        require(msg.sender == expectedWalletAddress, error_message_sender_is_not_good_wallet);

        tvm.accept();

        total_supply_ -= tokens;

        IBurnTokensCallback(callback_address).burnCallback{value: 0, flag: 64}(
            tokens,
            callback_payload,
            sender_public_key,
            sender_address,
            expectedWalletAddress
        );

    }

// =============== Support functions ==================

    modifier onlyOwner() {
        require(isOwner(), error_message_sender_is_not_my_owner);
        _;
    }

    modifier onlyInternalOwner() {
        require(isInternalOwner(), error_message_sender_is_not_my_owner);
        _;
    }

    function isOwner() private inline view returns (bool) {
        return isInternalOwner() || isExternalOwner();
    }

    function isInternalOwner() private inline view returns (bool) {
        return root_owner_address_.value != 0 && root_owner_address_ == msg.sender;
    }

    function isExternalOwner() private inline view returns (bool) {
        return root_public_key_ != 0 && root_public_key_ == tvm.pubkey();
    }

    function getExpectedWalletAddress(uint256 wallet_public_key, address owner_address) private inline view returns (address)  {
        TvmCell stateInit = tvm.buildStateInit({
            contr: TONTokenWallet,
            varInit: {
                name_: name_,
                symbol_: symbol_,
                decimals_: decimals_,
                root_address_: address(this),
                code_: wallet_code_,
                wallet_public_key_: wallet_public_key,
                owner_address_: owner_address
            },
            pubkey: wallet_public_key,
            code: wallet_code_
        });

        return address(tvm.hash(stateInit));
    }

    onBounce(TvmSlice slice) external {
        tvm.accept();
        uint32 functionId = slice.decode(uint32);
        if (functionId == tvm.functionId(ITONTokenWallet.accept)) {
            uint128 latest_bounced_tokens = slice.decode(uint128);
            total_supply_ -= latest_bounced_tokens;
        }
    }

    fallback() external {
    }

}
