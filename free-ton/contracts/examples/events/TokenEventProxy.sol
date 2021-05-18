pragma ton-solidity ^0.39.0;

pragma AbiHeader pubkey;
pragma AbiHeader expire;

import '../../../../node_modules/ton-eth-bridge-contracts/free-ton/contracts/interfaces/IProxy.sol';
import "../../../../node_modules/ton-eth-bridge-contracts/free-ton/contracts/interfaces/IEvent.sol";
import '../../../../node_modules/ton-eth-bridge-contracts/free-ton/contracts/event-contracts/EthereumEvent.sol';

import "../../interfaces/IReceiveSurplusGas.sol";
import "../../interfaces/ISendSurplusGas.sol";
import '../../interfaces/ITokensBurner.sol';
import '../../interfaces/IBurnTokensCallback.sol';
import '../../interfaces/IRootTokenContract.sol';
import '../../interfaces/IBurnableByRootTokenRootContract.sol';
import "../../interfaces/IPausedCallback.sol";
import "../../interfaces/IPausable.sol";
import "../../interfaces/ITransferOwner.sol";


contract TokenEventProxy is
    IProxy,
    IBurnTokensCallback,
    IPausable,
    ITransferOwner
{
    uint256 static _randomNonce;

    struct Configuration {
        TvmCell ethereum_event_code;
        address[] outdated_token_roots;
        uint256 ethereum_event_deploy_pubkey;
        address ethereum_event_configuration_address;
        address token_root_address;

        address root_tunnel;

        uint128 settings_deploy_wallet_grams;
    }

    Configuration public config;

    uint256 public external_owner_pubkey;
    address public internal_owner_address;

    uint128 public start_gas_balance;
    uint128 public burned_count;

    bool public paused = false;

    uint8 constant error_message_sender_is_not_my_owner = 100;
    uint8 constant error_message_sender_is_not_my_root = 102;
    uint8 constant error_message_sender_is_not_valid_event = 103;
    uint8 constant error_message_not_valid_payload = 104;
    uint8 constant error_define_public_key_or_owner_address = 106;
    uint8 constant error_paused = 107;
    uint8 constant error_wrong_tvm_key = 108;

    event TokenBurn(
        int8 wid,
        uint256 addr,
        uint128 tokens,
        uint160 ethereum_address
    );

    constructor(
        uint256 external_owner_pubkey_,
        address internal_owner_address_
    ) public {
        require(tvm.pubkey() == msg.pubkey(), error_wrong_tvm_key);
        require(
            (external_owner_pubkey_ != 0 && internal_owner_address_.value == 0) ||
            (external_owner_pubkey_ == 0 && internal_owner_address_.value != 0),
            error_define_public_key_or_owner_address
        );

        tvm.accept();

        external_owner_pubkey = external_owner_pubkey_;
        internal_owner_address = internal_owner_address_;

        start_gas_balance = address(this).balance;
    }

    function setConfiguration(Configuration _config) public onlyOwner {
        config = _config;
    }

    /*
        @notice Event contract callback
    */
    function broxusBridgeCallback(
        IEvent.EthereumEventInitData eventData,
        address gasBackAddress
    ) override public {
        require(!paused, error_paused);

        address expectedSenderAddress = getExpectedEventAddress(eventData);

        require(expectedSenderAddress == msg.sender, error_message_sender_is_not_valid_event);
        require(eventData.ethereumEventConfiguration == config.ethereum_event_configuration_address);
        require(eventData.proxyAddress == address(this));
        require(config.token_root_address.value != 0);

        tvm.rawReserve(
            math.max(start_gas_balance, address(this).balance - msg.value),
            2
        );

        (uint128 tokens, int8 wid, uint256 owner_addr, uint256 owner_pubkey) =
        eventData.eventData.toSlice().decode(uint128, int8, uint256, uint256);

        address owner_address = address.makeAddrStd(wid, owner_addr);

        require(tokens > 0, error_message_not_valid_payload);
        require((owner_pubkey != 0 && owner_address.value == 0) ||
        (owner_pubkey == 0 && owner_address.value != 0), error_message_not_valid_payload);

        IRootTokenContract(config.root_tunnel).deployWallet{ value: 0, flag: 128}(
            tokens,
            config.settings_deploy_wallet_grams,
            owner_pubkey,
            owner_address,
            gasBackAddress
        );
    }

    function burnCallbackV1(
        uint128 tokens,
        TvmCell /*payload*/,
        uint256 sender_public_key,
        address sender_address,
        address wallet_address
    ) external view functionID(0x71dd2774) {
        tvm.rawReserve(
            math.max(start_gas_balance, address(this).balance - msg.value),
            2
        );

        bool is_outdated_tokens = false;

        for (uint i=0; i < config.outdated_token_roots.length; i++) {
            is_outdated_tokens = is_outdated_tokens || config.outdated_token_roots[i] == msg.sender;
        }

        address send_gas_to;
        if (sender_address.value == 0) {
            send_gas_to = wallet_address;
        } else {
            send_gas_to = sender_address;
        }

        if (is_outdated_tokens) {
            IRootTokenContract(config.token_root_address).deployWallet{ value: 0, flag: 128}(
                tokens,
                config.settings_deploy_wallet_grams,
                sender_public_key,
                sender_address,
                send_gas_to
            );
        } else {
            send_gas_to.transfer({ value: 0, flag: 128 });
        }
    }

    function burnCallback(
        uint128 tokens,
        TvmCell payload,
        uint256 sender_public_key,
        address sender_address,
        address,
        address send_gas_to
    ) override external {
        tvm.rawReserve(
            math.max(start_gas_balance, address(this).balance - msg.value),
            2
        );

        if (config.token_root_address == msg.sender) {
            burned_count += tokens;

            (uint160 ethereum_address) = payload.toSlice().decode(uint160);

            emit TokenBurn(sender_address.wid, sender_address.value, tokens, ethereum_address);

            send_gas_to.transfer({ value: 0, flag: 128 });
        } else {
            bool is_outdated_tokens = false;

            for (uint i=0; i < config.outdated_token_roots.length; i++) {
                is_outdated_tokens = is_outdated_tokens || config.outdated_token_roots[i] == msg.sender;
            }

            if (is_outdated_tokens) {
                IRootTokenContract(config.token_root_address).deployWallet{ value: 0, flag: 128}(
                    tokens,
                    config.settings_deploy_wallet_grams,
                    sender_public_key,
                    sender_address,
                    send_gas_to
                );
            } else {
                send_gas_to.transfer({ value: 0, flag: 128 });
            }
        }
    }

    function withdrawExtraGasFromTokenRoot(
        address root,
        address to
    ) external pure onlyOwner {
        tvm.accept();

        ISendSurplusGas(root).sendSurplusGas(to);
    }

    // =============== IPausable ==================

    function setPaused(bool value) override external onlyOwner {
        tvm.accept();
        paused = value;
        IPausable(config.root_tunnel).setPaused(paused);
    }

    function sendPausedCallbackTo(uint64 callback_id, address callback_addr) override external {
        tvm.rawReserve(math.max(start_gas_balance, address(this).balance - msg.value), 2); //RESERVE_UP_TO
        IPausedCallback(callback_addr).pausedCallback{ value: 0, flag: 128 }(callback_id, paused);
    }

    // =============== Transfer owner ==================

    function transferOwner(
        uint256 external_owner_pubkey_,
        address internal_owner_address_
    ) override external onlyOwner {
        require((external_owner_pubkey_ != 0 && internal_owner_address_.value == 0) ||
        (external_owner_pubkey_ == 0 && internal_owner_address_.value != 0),
        error_define_public_key_or_owner_address);

        tvm.accept();

        external_owner_pubkey = external_owner_pubkey_;
        internal_owner_address = internal_owner_address_;
    }

    function transferOwnership(
        address target,
        uint256 external_owner_pubkey_,
        address internal_owner_address_
    ) external pure onlyOwner {
        require((external_owner_pubkey_ != 0 && internal_owner_address_.value == 0) ||
        (external_owner_pubkey_ == 0 && internal_owner_address_.value != 0),
        error_define_public_key_or_owner_address);

        tvm.accept();

        ITransferOwner(target).transferOwner(external_owner_pubkey_, internal_owner_address_);
    }

    // =============== Support functions ==================

    function token_root_address() external view returns (address) {
        return config.token_root_address;
    }

    function isRoot() private inline view returns (bool) {
        return config.token_root_address == msg.sender;
    }

    modifier onlyInternalOwner() {
        require(isInternalOwner(), error_message_sender_is_not_my_owner);
        _;
    }

    modifier onlyRoot() {
        require(isRoot(), error_message_sender_is_not_my_root);
        _;
    }

    modifier onlyOwner() {
        require(isOwner(), error_message_sender_is_not_my_owner);
        _;
    }

    function isOwner() private inline view returns (bool) {
        return isInternalOwner() || isExternalOwner();
    }

    function isInternalOwner() private inline view returns (bool) {
        return internal_owner_address.value != 0 && internal_owner_address == msg.sender;
    }

    function isExternalOwner() private inline view returns (bool) {
        return external_owner_pubkey != 0 && external_owner_pubkey == msg.pubkey();
    }

    function getExpectedEventAddress(
        IEvent.EthereumEventInitData initData
    ) public view returns (address) {
        TvmCell stateInit = tvm.buildStateInit({
            contr: EthereumEvent,
            varInit: {
                initData: initData
            },
            pubkey: config.ethereum_event_deploy_pubkey,
            code: config.ethereum_event_code
        });

        return address(tvm.hash(stateInit));
    }
}
