pragma solidity >= 0.6.0;

pragma AbiHeader time;
pragma AbiHeader expire;

import '../interfaces/IProxy.sol';
import "../interfaces/IEvent.sol";
import '../bridge/EthereumEvent.sol';
import '../../interfaces/ITokensBurner.sol';
import '../../interfaces/IBurnTokensCallback.sol';
import '../../interfaces/IRootTokenContract.sol';
import '../../interfaces/IBurnableByRootTokenRootContract.sol';
import "../../interfaces/IPausedCallback.sol";
import "../../interfaces/IPausable.sol";
import "../../interfaces/ITransferOwner.sol";


contract TokenEventProxy is IProxy, IBurnTokensCallback, ITokensBurner, IPausable, ITransferOwner {

    uint256 static _randomNonce;
    TvmCell static ethereum_event_code;

    uint256 public external_owner_pubkey;
    address public internal_owner_address;

    uint256 public ethereum_event_deploy_pubkey;
    address public ethereum_event_configuration_address;
    address public token_root_address;

    uint128 public settings_burn_min_msg_value = 1 ton;
    uint128 public settings_deploy_wallet_grams = 0.05 ton;

    uint128 public start_gas_balance;
    uint128 public burned_count;

    bool public paused = false;

    uint8 error_message_sender_is_not_my_owner = 100;
    uint8 error_message_sender_is_not_my_root = 102;
    uint8 error_message_sender_is_not_valid_event = 103;
    uint8 error_message_not_valid_payload = 104;
    uint8 error_define_public_key_or_owner_address = 106;
    uint8 error_paused = 107;

    event TokenBurn(
        int8 wid,
        uint256 addr,
        uint128 tokens,
        uint160 ethereum_address
    );

    constructor(uint256 external_owner_pubkey_, address internal_owner_address_) public {
        require((external_owner_pubkey_ != 0 && internal_owner_address_.value == 0) ||
                (external_owner_pubkey_ == 0 && internal_owner_address_.value != 0),
                error_define_public_key_or_owner_address);
        tvm.accept();
        external_owner_pubkey = external_owner_pubkey_;
        internal_owner_address = internal_owner_address_;

        ethereum_event_deploy_pubkey = 0;
        ethereum_event_configuration_address = address.makeAddrStd(0, 0);
        token_root_address = address.makeAddrStd(0, 0);
        start_gas_balance = address(this).balance;
    }

    function broxusBridgeCallback(
        IEvent.EthereumEventInitData eventData,
        address gasBackAddress
    ) override public {

        require(!paused, error_paused);

        address expectedSenderAddress = getExpectedEventAddress(eventData);

        require(expectedSenderAddress == msg.sender, error_message_sender_is_not_valid_event);
        require(eventData.ethereumEventConfiguration == ethereum_event_configuration_address);
        require(eventData.proxyAddress == address(this));
        require(token_root_address.value != 0);

        tvm.accept();
        tvm.rawReserve(math.max(start_gas_balance, address(this).balance - msg.value), 2); //RESERVE_UP_TO

        (uint128 tokens, int8 wid, uint256 owner_addr, uint256 owner_pubkey) =
            eventData.eventData.toSlice().decode(uint128, int8, uint256, uint256);

        address owner_address = address.makeAddrStd(wid, owner_addr);

        require(tokens > 0, error_message_not_valid_payload);
        require((owner_pubkey != 0 && owner_address.value == 0) ||
                (owner_pubkey == 0 && owner_address.value != 0), error_message_not_valid_payload);

        IRootTokenContract(token_root_address).deployWallet{ value: 0, flag: 128}(
            tokens,
            settings_deploy_wallet_grams,
            owner_pubkey,
            owner_address,
            gasBackAddress
        );
    }

    function burnCallback(
        uint128 tokens,
        TvmCell payload,
        uint256,
        address sender_address,
        address wallet_address
    ) override external onlyRoot {

        tvm.accept();
        tvm.rawReserve(math.max(start_gas_balance, address(this).balance - msg.value), 2); //RESERVE_UP_TO

        burned_count += tokens;

        (uint160 ethereum_address) = payload.toSlice().decode(uint160);

        emit TokenBurn(sender_address.wid, sender_address.value, tokens, ethereum_address);

        if (sender_address.value == 0) {
            wallet_address.transfer({ value: 0, flag: 128 });
        } else {
            sender_address.transfer({ value: 0, flag: 128 });
        }
    }

    function transferMyTokensToEthereum(uint128 tokens, uint160 ethereum_address) external view {
        require(!paused, error_paused);
        require(tokens > 0);
        require(ethereum_address != 20);
        require(token_root_address.value != 0);
        require(msg.sender.value != 0);
        require(msg.value >= settings_burn_min_msg_value);
        tvm.accept();
        tvm.rawReserve(math.max(start_gas_balance, address(this).balance - msg.value), 2); //RESERVE_UP_TO

        TvmBuilder builder;
        builder.store(ethereum_address);
        TvmCell callback_payload = builder.toCell();

        IBurnableByRootTokenRootContract(token_root_address).proxyBurn{value: 0, flag: 128}(
            tokens,
            msg.sender,
            address(this),
            callback_payload
        );
    }

    function burnMyTokens(uint128 tokens, address callback_address, TvmCell callback_payload) override external {
        require(!paused, error_paused);
        require(tokens > 0);
        require(token_root_address.value != 0);
        require(msg.sender.value != 0);
        require(msg.value >= settings_burn_min_msg_value);
        tvm.accept();
        tvm.rawReserve(math.max(start_gas_balance, address(this).balance - msg.value), 2); //RESERVE_UP_TO
        IBurnableByRootTokenRootContract(token_root_address).proxyBurn{value: 0, flag: 128}(
            tokens,
            msg.sender,
            callback_address,
            callback_payload
        );
    }

    function withdrawExtraGasFromTokenRoot() external view onlyOwner {
        tvm.accept();
        IRootTokenContract(token_root_address).withdrawExtraGas();
    }

    function withdrawExtraGas() external view onlyInternalOwner {
        tvm.rawReserve(start_gas_balance, 2);
        internal_owner_address.transfer({ value: 0, flag: 128 });
    }

    // =============== IPausable ==================

    function setPaused(bool value) override external onlyOwner {
        tvm.accept();
        paused = value;
        IPausable(token_root_address).setPaused(paused);
    }

    function sendPausedCallbackTo(uint64 callback_id, address callback_addr) override external {
        tvm.rawReserve(math.max(start_gas_balance, address(this).balance - msg.value), 2); //RESERVE_UP_TO
        IPausedCallback(callback_addr).pausedCallback{ value: 0, flag: 128 }(callback_id, paused);
    }

    // =============== Transfer owner ==================

    function transferOwner(uint256 external_owner_pubkey_, address internal_owner_address_) override external onlyOwner {
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
    ) external view onlyOwner {
        require((external_owner_pubkey_ != 0 && internal_owner_address_.value == 0) ||
                (external_owner_pubkey_ == 0 && internal_owner_address_.value != 0),
                error_define_public_key_or_owner_address);
        tvm.accept();
        ITransferOwner(target).transferOwner(external_owner_pubkey_, internal_owner_address_);
    }

    // =============== Settings ==================

    function setTokenRootAddressOnce(address value) external onlyOwner {
        require(token_root_address.value == 0);
        tvm.accept();
        token_root_address = value;
    }

    function setEthEventDeployPubkeyOnce(uint256 value) external onlyOwner {
        require(ethereum_event_deploy_pubkey == 0);
        tvm.accept();
        ethereum_event_deploy_pubkey = value;
    }

    function setEthEventConfigAddressOnce(address value) external onlyOwner {
        require(ethereum_event_configuration_address.value == 0);
        tvm.accept();
        ethereum_event_configuration_address = value;
    }

    function setBurnMinMsgValue(uint128 value) external onlyOwner {
        tvm.accept();
        settings_burn_min_msg_value = value;
    }

    function setDeployWalletGrams(uint128 value) external onlyOwner {
        tvm.accept();
        settings_deploy_wallet_grams = value;
    }

    function setEthereumEventCode(TvmCell value) external onlyOwner {
        tvm.accept();
        ethereum_event_code = value;
    }

    // =============== Support functions ==================

    function isRoot() private inline view returns (bool) {
        return token_root_address == msg.sender;
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
        return external_owner_pubkey != 0 && external_owner_pubkey == tvm.pubkey();
    }

    function getExpectedEventAddress(IEvent.EthereumEventInitData initData) private inline view returns (address)  {
        TvmCell stateInit = tvm.buildStateInit({
            contr: EthereumEvent,
            varInit: { initData: initData },
            pubkey: ethereum_event_deploy_pubkey,
            code: ethereum_event_code
        });

        return address(tvm.hash(stateInit));
    }

}
