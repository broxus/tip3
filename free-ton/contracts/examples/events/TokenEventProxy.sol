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


contract TokenEventProxy is IProxy, IBurnTokensCallback, ITokensBurner {

    uint256 static _randomNonce;

    uint256 static external_owner_pubkey;
    address static internal_owner_address;

    TvmCell static ethereum_event_code;

    uint256 ethereum_event_deploy_pubkey;
    address ethereum_event_configuration_address;
    address token_root_address;

    uint128 settings_burn_min_msg_value = 2 ton;
    uint128 settings_deploy_wallet_grams = 0.1 ton;
    uint128 settings_deploy_wallet_value = 5 ton;

    uint128 start_balance_;
    uint128 burned_count;

    uint8 error_message_sender_is_not_my_owner = 100;
    uint8 error_message_sender_is_not_my_root = 102;
    uint8 error_message_sender_is_not_valid_event = 103;
    uint8 error_message_not_valid_payload = 104;

    event TokenBurn(
        uint128 tokens,
        bytes ethereum_address
    );

    constructor() public {
        tvm.accept();
        ethereum_event_deploy_pubkey = 0;
        ethereum_event_configuration_address = address.makeAddrStd(0, 0);
        token_root_address = address.makeAddrStd(0, 0);
        start_balance_ = address(this).balance;
    }

    function broxusBridgeCallback(IEvent.EthereumEventInitData eventData) override public {

        address expectedSenderAddress = getExpectedEventAddress(eventData);

        require(expectedSenderAddress == msg.sender, error_message_sender_is_not_valid_event);
        require(eventData.ethereumEventConfiguration == ethereum_event_configuration_address);
        require(eventData.proxyAddress == address(this));
        require(token_root_address.value != 0);

        tvm.accept();

        (uint128 tokens, int8 wid, uint256 owner_addr, uint256 owner_pubkey) =
            eventData.eventData.toSlice().decode(uint128, int8, uint256, uint256);

        address owner_address = address.makeAddrStd(wid, owner_addr);

        require(tokens > 0, error_message_not_valid_payload);
        require((owner_pubkey != 0 && owner_address.value == 0) ||
                (owner_pubkey == 0 && owner_address.value != 0), error_message_not_valid_payload);

        IRootTokenContract(token_root_address).deployWallet{ value: settings_deploy_wallet_value }(
            tokens,
            settings_deploy_wallet_grams,
            owner_pubkey,
            owner_address,
            address(this)
        );
    }

    function broxusBridgeNotification(
        IEvent.EthereumEventInitData _eventData
    ) override public view {
        // Do nothing need for handy monitoring confirmed events
        // So someone can call them after with any gas
    }

    function burnCallback(
        uint128 tokens,
        TvmCell payload,
        uint256 sender_public_key,
        address sender_address,
        address wallet_address
    ) override external onlyRoot {

        tvm.accept();
        tvm.rawReserve(math.max(start_balance_, address(this).balance - msg.value), 2); //RESERVE_UP_TO

        burned_count += tokens;

        (bytes ethereum_address) = payload.toSlice().decode(bytes);

        emit TokenBurn(tokens, ethereum_address);

        if (sender_address.value == 0) {
            wallet_address.transfer({ value: 0, flag: 128 });
        } else {
            sender_address.transfer({ value: 0, flag: 128 });
        }
    }

    function transferMyTokensToEthereum(uint128 tokens, bytes ethereum_address) external {
        require(ethereum_address.length  == 20);
        require(token_root_address.value != 0);
        require(msg.sender.value != 0);
        require(msg.value >= settings_burn_min_msg_value);
        tvm.accept();
        tvm.rawReserve(math.max(start_balance_, address(this).balance - msg.value), 2); //RESERVE_UP_TO

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
        require(token_root_address.value != 0);
        require(msg.sender.value != 0);
        require(msg.value >= settings_burn_min_msg_value);
        tvm.accept();
        tvm.rawReserve(math.max(start_balance_, address(this).balance - msg.value), 2); //RESERVE_UP_TO
        IBurnableByRootTokenRootContract(token_root_address).proxyBurn{value: 0, flag: 128}(
            tokens,
            msg.sender,
            callback_address,
            callback_payload
        );
    }

    function getTokenRootAddress() external view returns (address) {
        return token_root_address;
    }

    function getEthEventDeployPubkey() external view returns (uint256) {
        return ethereum_event_deploy_pubkey;
    }

    function getEthEventConfigAddress() external view returns (address) {
        return ethereum_event_configuration_address;
    }

    function getBurnMinMsgValue() external view returns (uint128) {
        return settings_burn_min_msg_value;
    }

    function getDeployWalletGrams() external view returns (uint128) {
        return settings_deploy_wallet_grams;
    }

    function getDeployWalletValue() external view returns (uint128) {
        return settings_deploy_wallet_value;
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

    function setDeployWalletValue(uint128 value) external onlyOwner {
        tvm.accept();
        settings_deploy_wallet_value = value;
    }

    // =============== Support functions ==================

    function isRoot() private inline view returns (bool) {
        return token_root_address == msg.sender;
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
