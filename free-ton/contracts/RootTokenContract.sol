pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/IBurnableByRootTokenWallet.sol";
import "./interfaces/IBurnableTokenRootContract.sol";
import "./interfaces/IBurnableByRootTokenRootContract.sol";
import "./interfaces/IExpectedWalletAddressCallback.sol";
import "./interfaces/IBurnTokensCallback.sol";
import "./interfaces/IRootTokenContract.sol";
import "./interfaces/ITONTokenWallet.sol";
import "./interfaces/IReceiveSurplusGas.sol";
import "./interfaces/ISendSurplusGas.sol";
import "./TONTokenWallet.sol";
import "./interfaces/IPausable.sol";
import "./interfaces/IPausedCallback.sol";
import "./interfaces/ITransferOwner.sol";
import "./libraries/RootTokenContractErrors.sol";
import "./interfaces/IVersioned.sol";


/*
    @title FT token root contract
*/
contract RootTokenContract is
IRootTokenContract, IBurnableTokenRootContract, IBurnableByRootTokenRootContract,
IPausable, ITransferOwner, ISendSurplusGas, IVersioned {

    uint256 static _randomNonce;

    bytes public static name;
    bytes public static symbol;
    uint8 public static decimals;

    TvmCell static wallet_code;

    uint128 total_supply;

    uint256 root_public_key;
    address root_owner_address;
    uint128 public start_gas_balance;

    bool public paused;

    /*
        @param root_public_key_ Root token owner public key
        @param root_owner_address_ Root token owner address
    */
    constructor(uint256 root_public_key_, address root_owner_address_) public {
        require((root_public_key_ != 0 && root_owner_address_.value == 0) ||
                (root_public_key_ == 0 && root_owner_address_.value != 0),
                RootTokenContractErrors.error_define_public_key_or_owner_address);
        tvm.accept();

        root_public_key = root_public_key_;
        root_owner_address = root_owner_address_;

        total_supply = 0;
        paused = false;

        start_gas_balance = address(this).balance;
    }

    function getVersion() override external pure responsible returns (uint32) {
        return 4;
    }

    /*
        @notice Get root token details
        @returns name Token name
        @returns symbol Token symbol
        @returns decimals Token decimals
        @returns wallet_code Source code for Token wallet
        @returns root_public_key Owner public key
        @returns root_owner_address Owner address
        @returns total_supply Token total supply
    */
    function getDetails() override external view responsible returns (IRootTokenContractDetails) {
        return { value: 0, bounce: false, flag: 64 } IRootTokenContractDetails(
            name,
            symbol,
            decimals,
            root_public_key,
            root_owner_address,
            total_supply
        );
    }

    /*
        @notice Get total supply
        @returns total_supply Token total supply
    */
    function getTotalSupply() override external view responsible returns (uint128) {
        return { value: 0, bounce: false, flag: 64 } total_supply;
    }

    /*
        @notice Get Token wallet code
        @returns code Token wallet code
    */
    function getWalletCode() override external view responsible returns (TvmCell) {
        return { value: 0, bounce: false, flag: 64 } wallet_code;
    }

    /*
        @notice Derive token wallet address from the public key or address
        @dev Since the token wallet can be controlled through key or address, both options are supported
        @param wallet_public_key_ Token wallet owner public key
        @param owner_address_ Token wallet owner address
        @returns Token wallet address
    */
    function getWalletAddress(
        uint256 wallet_public_key_,
        address owner_address_
    )
        override
        external
        view
        responsible
    returns (
        address
    ) {
        require((owner_address_.value != 0 && wallet_public_key_ == 0) ||
                (owner_address_.value == 0 && wallet_public_key_ != 0),
                RootTokenContractErrors.error_define_public_key_or_owner_address);
        return { value: 0, bounce: false, flag: 64 } getExpectedWalletAddress(wallet_public_key_, owner_address_);
    }

    /*
        @notice Allows any contract to receive token wallet address in expectedWalletAddressCallback method
        @param wallet_public_key_ Token wallet owner public key
        @param owner_address_ Token wallet owner address
        @param to Callback receiver
    */
    function sendExpectedWalletAddress(
        uint256 wallet_public_key_,
        address owner_address_,
        address to
    )
        override
        external
    {
        tvm.rawReserve(address(this).balance - msg.value, 2);

        address wallet = getExpectedWalletAddress(wallet_public_key_, owner_address_);
        IExpectedWalletAddressCallback(to).expectedWalletAddressCallback{value: 0, flag: 128}(
            wallet,
            wallet_public_key_,
            owner_address_
        );
    }

    /*
        @notice Deploy token wallet
        @dev Can be called only by owner
        @dev Can be called both by owner key or address
        @dev wallet_public_key_ or owner_address_ should be specified!
        @param tokens How much tokens to send
        @param deploy_grams How much TONs send to wallet on deployment
        @param wallet_public_key_ Token wallet owner public key
        @param owner_address_ Token wallet owner address
        @param gas_back_address Receiver the remaining balance after deployment. msg.sender by default
        @returns Token wallet address
    */
    function deployWallet(
        uint128 tokens,
        uint128 deploy_grams,
        uint256 wallet_public_key_,
        address owner_address_,
        address gas_back_address
    )
        override
        external
        onlyOwner
    returns(
        address
    ) {
        require(tokens >= 0);
        require((owner_address_.value != 0 && wallet_public_key_ == 0) ||
                (owner_address_.value == 0 && wallet_public_key_ != 0),
                RootTokenContractErrors.error_define_public_key_or_owner_address);

        if(root_owner_address.value == 0) {
            tvm.accept();
        } else {
            tvm.rawReserve(math.max(start_gas_balance, address(this).balance - msg.value), 2);
        }

        TvmCell stateInit = tvm.buildStateInit({
            contr: TONTokenWallet,
            varInit: {
                root_address: address(this),
                code: wallet_code,
                wallet_public_key: wallet_public_key_,
                owner_address: owner_address_
            },
            pubkey: wallet_public_key_,
            code: wallet_code
        });

        address wallet;

        if(deploy_grams > 0) {
            wallet = new TONTokenWallet{
                stateInit: stateInit,
                value: deploy_grams,
                wid: address(this).wid,
                flag: 1
            }();
        } else {
            wallet = address(tvm.hash(stateInit));
        }

        ITONTokenWallet(wallet).accept(tokens);

        total_supply += tokens;

        if (root_owner_address.value != 0) {
            if (gas_back_address.value != 0) {
                gas_back_address.transfer({ value: 0, flag: 128 });
            } else {
                msg.sender.transfer({ value: 0, flag: 128 });
            }
        }

        return wallet;
    }

    /*
        @notice Deploy new token wallet with empty tokens balance
        @dev Can be called by anyone to deploy new token wallet
        @dev wallet_public_key_ or owner_address_ should be specified!
        @param wallet_public_key_ Token wallet owner public key
        @param owner_address_ Token wallet owner address
        @param gas_back_address Receiver the remaining balance after deployment. msg.sender by default
        @returns Token wallet address
    */
    function deployEmptyWallet(
        uint128 deploy_grams,
        uint256 wallet_public_key_,
        address owner_address_,
        address gas_back_address
    )
        override
        external
    returns (
        address
    ) {
        require((owner_address_.value != 0 && wallet_public_key_ == 0) ||
                (owner_address_.value == 0 && wallet_public_key_ != 0),
                RootTokenContractErrors.error_define_public_key_or_owner_address);

        tvm.rawReserve(address(this).balance - msg.value, 2);

        address wallet = new TONTokenWallet{
            value: deploy_grams,
            flag: 1,
            code: wallet_code,
            pubkey: wallet_public_key_,
            varInit: {
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

        return wallet;
    }

    /*
        @notice Mint new tokens to token wallet
        @dev Can be called only by owner
        @param tokens How much tokens to mint
        @param to Receiver token wallet address
    */
    function mint(
        uint128 tokens,
        address to
    )
        override
        external
        onlyOwner
    {
        tvm.accept();

        ITONTokenWallet(to).accept(tokens);

        total_supply += tokens;
    }

    /*
        @notice Burn tokens at specific token wallet
        @dev Can be called only by owner address
        @dev Don't support token wallet owner public key
        @param tokens How much tokens to burn
        @param sender_address Token wallet owner address
        @param send_gas_to Receiver of the remaining balance after burn. sender_address by default
        @param callback_address Burn callback address
        @param callback_payload Burn callback payload
    */
    function proxyBurn(
        uint128 tokens,
        address sender_address,
        address send_gas_to,
        address callback_address,
        TvmCell callback_payload
    )
        override
        external
        onlyInternalOwner
    {
        tvm.rawReserve(address(this).balance - msg.value, 2);

        address send_gas_to_ = send_gas_to;
        address expectedWalletAddress = getExpectedWalletAddress(0, sender_address);

        if (send_gas_to.value == 0) {
            send_gas_to_ = sender_address;
        }

        IBurnableByRootTokenWallet(expectedWalletAddress).burnByRoot{value: 0, flag: 128}(
            tokens,
            send_gas_to_,
            callback_address,
            callback_payload
        );
    }

    /*
        @notice Callback for token wallet tokens burn operation
        @dev Decrease total supply
        @dev Can be called only by correct token wallet contract
        @dev Fails if root token is paused
        @param tokens How much tokens was burned
        @param sender_public_key Token wallet owner public key
        @param sender_address Token wallet owner address
        @param send_gas_to Remaining balance receiver
        @param callback_address Callback receiver address
        @param callback_payload Callback payload
    */
    function tokensBurned(
        uint128 tokens,
        uint256 sender_public_key,
        address sender_address,
        address send_gas_to,
        address callback_address,
        TvmCell callback_payload
    ) override external {

        require(!paused, RootTokenContractErrors.error_paused);

        address expectedWalletAddress = getExpectedWalletAddress(sender_public_key, sender_address);

        require(msg.sender == expectedWalletAddress, RootTokenContractErrors.error_message_sender_is_not_good_wallet);

        tvm.rawReserve(address(this).balance - msg.value, 2);

        total_supply -= tokens;

        if (callback_address.value == 0) {
            send_gas_to.transfer({ value: 0, flag: 128 });
        } else {
            IBurnTokensCallback(callback_address).burnCallback{value: 0, flag: 128}(
                tokens,
                callback_payload,
                sender_public_key,
                sender_address,
                expectedWalletAddress,
                send_gas_to
            );
        }

    }

    /*
        @notice Withdraw all surplus balance in TONs
        @dev Can by called only by owner address
        @param to Withdraw receiver
    */
    function sendSurplusGas(
        address to
    )
        override
        external
        onlyInternalOwner
    {
        tvm.rawReserve(start_gas_balance, 2);
        IReceiveSurplusGas(to).receiveSurplusGas{ value: 0, flag: 128 }();
    }

    // =============== IPausable ==================

    /*
        @notice Pause / unpause root token
        @dev Can be called only by owner
        @dev Can't stop transfers since it's an operation directly between token wallets
        @dev Pause disables / enables token burning
        @dev Paused value should be used on wallet applications level
        @param value Pause / unpause
    */
    function setPaused(
        bool value
    )
        override
        external
        onlyOwner
    {
        tvm.accept();
        paused = value;
    }

    /*
        @notice Notify some contract with current paused status
        @param callback_id Request id
        @param callback_addr Callback receiver
    */
    function sendPausedCallbackTo(
        uint64 callback_id,
        address callback_addr
    )
        override
        external
    {
        tvm.rawReserve(address(this).balance - msg.value, 2);
        IPausedCallback(callback_addr).pausedCallback{ value: 0, flag: 128 }(callback_id, paused);
    }


    /*
        @notice Transfer root token ownership
        @param root_public_key_ Root token owner public key
        @param root_owner_address_ Root token owner address
    */
    function transferOwner(
        uint256 root_public_key_,
        address root_owner_address_
    )
        override
        external
        onlyOwner
    {
        require((root_public_key_ != 0 && root_owner_address_.value == 0) ||
                (root_public_key_ == 0 && root_owner_address_.value != 0),
                RootTokenContractErrors.error_define_public_key_or_owner_address);
        tvm.accept();
        root_public_key = root_public_key_;
        root_owner_address = root_owner_address_;
    }

    // =============== Support functions ==================

    modifier onlyOwner() {
        require(isOwner(), RootTokenContractErrors.error_message_sender_is_not_my_owner);
        _;
    }

    modifier onlyInternalOwner() {
        require(isInternalOwner(), RootTokenContractErrors.error_message_sender_is_not_my_owner);
        _;
    }

    function isOwner() private inline view returns (bool) {
        return isInternalOwner() || isExternalOwner();
    }

    function isInternalOwner() private inline view returns (bool) {
        return root_owner_address.value != 0 && root_owner_address == msg.sender;
    }

    function isExternalOwner() private inline view returns (bool) {
        return root_public_key != 0 && root_public_key == msg.pubkey();
    }

    /*
        @notice Derive wallet address from owner
        @param wallet_public_key_ Token wallet owner public key
        @param owner_address_ Token wallet owner address
    */
    function getExpectedWalletAddress(
        uint256 wallet_public_key_,
        address owner_address_
    )
        private
        inline
        view
    returns (
        address
    ) {
        TvmCell stateInit = tvm.buildStateInit({
            contr: TONTokenWallet,
            varInit: {
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

    /*
        @notice On-bounce handler
        @dev Used in case token wallet .accept fails so the total_supply can be decreased back
    */
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
