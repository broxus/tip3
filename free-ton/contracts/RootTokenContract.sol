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

    bytes public static name;
    bytes public static symbol;
    uint8 public static decimals;
    TvmCell public static wallet_code;
    uint256 static root_public_key;
    address static root_owner_address;

    uint128 public total_supply;

    uint128 public start_gas_balance;

    uint8 error_message_sender_is_not_my_owner = 100;
    uint8 error_not_enough_balance = 101;
    uint8 error_message_sender_is_not_good_wallet = 103;
    uint8 error_define_wallet_public_key_or_owner_address = 106;

    constructor() public {
        require((root_public_key != 0 && root_owner_address.value == 0) ||
                (root_public_key == 0 && root_owner_address.value != 0),
                error_define_wallet_public_key_or_owner_address);
        tvm.accept();

        total_supply = 0;

        start_gas_balance = address(this).balance;
    }

    function getDetails() override external view returns (IRootTokenContractDetails) {
        return IRootTokenContractDetails(
            name,
            symbol,
            decimals,
            wallet_code,
            root_public_key,
            root_owner_address,
            total_supply,
            start_gas_balance
        );
    }

    function getWalletAddress(uint256 wallet_public_key_, address owner_address_) override external returns (address) {
        require((owner_address_.value != 0 && wallet_public_key_ == 0) ||
                (owner_address_.value == 0 && wallet_public_key_ != 0),
                error_define_wallet_public_key_or_owner_address);
        address walletAddress = getExpectedWalletAddress(wallet_public_key_, owner_address_);
        return walletAddress;
    }

    function deployWallet(
        uint128 tokens,
        uint128 grams,
        uint256 wallet_public_key_,
        address owner_address_,
        address gas_back_address
    ) override external onlyOwner {
        require(tokens >= 0);
        require((owner_address_.value != 0 && wallet_public_key_ == 0) ||
                (owner_address_.value == 0 && wallet_public_key_ != 0),
                error_define_wallet_public_key_or_owner_address);

        if(root_owner_address.value == 0) {
            tvm.accept();
        } else {
            tvm.rawReserve(math.max(start_gas_balance, address(this).balance - msg.value), 2); 
        }

        address wallet = new TONTokenWallet{
            value: grams,
            code: wallet_code,
            pubkey: wallet_public_key_,
            varInit: {
                name: name,
                symbol: symbol,
                decimals: decimals,
                root_address: address(this),
                code: wallet_code,
                wallet_public_key: wallet_public_key_,
                owner_address: owner_address_
            }
        }();

        ITONTokenWallet(wallet).accept(tokens);

        total_supply += tokens;

        if (root_owner_address.value != 0) {
            if (gas_back_address.value != 0) {
                gas_back_address.transfer({ value: 0, flag: 128 }); 
            } else {
                msg.sender.transfer({ value: 0, flag: 128 }); 
            }
        }
    }

    function deployEmptyWallet(
        uint128 grams,
        uint256 wallet_public_key_,
        address owner_address_,
        address gas_back_address
    ) override external {
        require((owner_address_.value != 0 && wallet_public_key_ == 0) ||
                (owner_address_.value == 0 && wallet_public_key_ != 0),
                error_define_wallet_public_key_or_owner_address);

        tvm.rawReserve(math.max(start_gas_balance, address(this).balance - msg.value), 2); 

        new TONTokenWallet{
            value: grams,
            code: wallet_code,
            pubkey: wallet_public_key_,
            varInit: {
                name: name,
                symbol: symbol,
                decimals: decimals,
                root_address: address(this),
                code: wallet_code,
                wallet_public_key: wallet_public_key_,
                owner_address: owner_address_
            }
        }();

        if (gas_back_address.value != 0) {
            gas_back_address.transfer({ value: 0, flag: 128 }); 
        } else {
            msg.sender.transfer({ value: 0, flag: 128 }); 
        }
    }

    function mint(uint128 tokens, address to) override external onlyOwner {
        if(root_owner_address.value == 0) {
            tvm.accept();
        } else {
            tvm.rawReserve(math.max(start_gas_balance, address(this).balance - msg.value), 2); 
        }

        total_supply += tokens;

        ITONTokenWallet(to).accept(tokens);

        if(root_owner_address.value != 0) {
            root_owner_address.transfer({ value: 0, flag: 128 }); 
        }
    }


    function proxyBurn(
        uint128 tokens,
        address sender_address,
        address callback_address,
        TvmCell callback_payload
    ) override external onlyInternalOwner {
        tvm.rawReserve(address(this).balance - msg.value, 2); 
        address expectedWalletAddress = getExpectedWalletAddress(0, sender_address);
        IBurnableByRootTokenWallet(expectedWalletAddress).burnByRoot{value: 0, flag: 128}( 
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

        tvm.rawReserve(address(this).balance - msg.value, 2); 

        total_supply -= tokens;

        IBurnTokensCallback(callback_address).burnCallback{value: 0, flag: 128}( 
            tokens,
            callback_payload,
            sender_public_key,
            sender_address,
            expectedWalletAddress
        );

    }

    function withdrawExtraGas() override external onlyInternalOwner {
        tvm.rawReserve(start_gas_balance, 2);
        root_owner_address.transfer({ value: 0, flag: 128 });
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
        return root_owner_address.value != 0 && root_owner_address == msg.sender;
    }

    function isExternalOwner() private inline view returns (bool) {
        return root_public_key != 0 && root_public_key == tvm.pubkey();
    }

    function getExpectedWalletAddress(uint256 wallet_public_key_, address owner_address_) private inline view returns (address)  {
        TvmCell stateInit = tvm.buildStateInit({
            contr: TONTokenWallet,
            varInit: {
                name: name,
                symbol: symbol,
                decimals: decimals,
                root_address: address(this),
                code: wallet_code,
                wallet_public_key: wallet_public_key_,
                owner_address: owner_address_
            },
            pubkey: wallet_public_key_,
            code: wallet_code
        });

        return address(tvm.hash(stateInit));
    }

    onBounce(TvmSlice slice) external {
        tvm.accept();
        uint32 functionId = slice.decode(uint32);
        if (functionId == tvm.functionId(ITONTokenWallet.accept)) {
            uint128 latest_bounced_tokens = slice.decode(uint128);
            total_supply -= latest_bounced_tokens;
        }
    }

    fallback() external {
    }

}
