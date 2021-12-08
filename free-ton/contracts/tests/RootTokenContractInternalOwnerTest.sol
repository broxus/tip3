pragma ton-solidity >= 0.39.0;

pragma AbiHeader pubkey;
pragma AbiHeader expire;

import "../interfaces/IRootTokenContract.sol";
import "../interfaces/IReceiveSurplusGas.sol";
import "../interfaces/ISendSurplusGas.sol";
import "../interfaces/IBurnTokensCallback.sol";
import "../interfaces/ITokensBurner.sol";
import "../interfaces/IBurnableByRootTokenRootContract.sol";

contract RootTokenContractInternalOwnerTest is IBurnTokensCallback, ITokensBurner, IReceiveSurplusGas {

    uint256 static _randomNonce;

    uint256 static external_owner_pubkey_;
    address static internal_owner_address_;

    address root_address_;

    uint128 start_gas_balance_;

    uint8 error_message_sender_is_not_my_owner = 100;
    uint8 error_message_sender_is_not_my_root = 102;

    uint128 settings_burn_min_value = 2 ton;
    uint128 settings_deploy_value = 1 ton;

    constructor() public {
        tvm.accept();
        root_address_ = address.makeAddrStd(0, 0);
        start_gas_balance_ = address(this).balance;
    }

    function setRootAddressOnce(address root_address) external onlyOwner {
        require(root_address_.value == 0);
        tvm.accept();
        root_address_ = root_address;
    }

    function getRootAddress() external view returns (address) {
        return root_address_;
    }

    function burnCallback(
        uint128 tokens,
        TvmCell payload,
        uint256,
        address,
        address,
        address send_gas_to
    ) override external onlyRoot {

        tvm.rawReserve(address(this).balance - msg.value, 2);

        burned_count += tokens;
        latest_payload = payload;

        send_gas_to.transfer({ value: 0, flag: 128 });
    }

    function burnMyTokens(
        uint128 tokens,
        address send_gas_to,
        address callback_address,
        TvmCell callback_payload
    ) override external {
        require(root_address_.value != 0);
        require(msg.sender.value != 0);
        require(msg.value >= settings_burn_min_value);
        tvm.rawReserve(address(this).balance - msg.value, 2);
        IBurnableByRootTokenRootContract(root_address_).proxyBurn{value: 0, flag: 128}(
            tokens,
            msg.sender,
            send_gas_to,
            callback_address,
            callback_payload
        );
    }

    function isRoot() private inline view returns (bool) {
        return root_address_ == msg.sender;
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
        return internal_owner_address_.value != 0 && internal_owner_address_ == msg.sender;
    }

    function isExternalOwner() private inline view returns (bool) {
        return external_owner_pubkey_ != 0 && external_owner_pubkey_ == msg.pubkey();
    }

    //only for tests
    uint128 burned_count;
    TvmCell latest_payload;

    function getBurnedCount() external view returns (uint128) {
        return burned_count;
    }

    function getLatestPayload() external view returns (TvmCell) {
        return latest_payload;
    }

    //key or addr
    function deployWallet(uint128 tokens, uint128 grams, uint256 pubkey, address addr) external view onlyOwner {
        require(root_address_.value != 0);
        tvm.accept();
        IRootTokenContract(root_address_).deployWallet{value: (grams + settings_deploy_value)}(
            tokens,
            grams,
            pubkey,
            addr,
            address(this)
        );
    }

    function mint(uint128 tokens, address addr) external view onlyOwner {
        require(root_address_.value != 0);
        tvm.accept();
        IRootTokenContract(root_address_).mint(tokens, addr);
    }

    function sendGramsToRoot(uint128 grams) external view onlyOwner {
        tvm.accept();
        root_address_.transfer({ value: grams });
    }

    function testWithdrawExtraGas() external view onlyOwner {
        tvm.accept();
        ISendSurplusGas(root_address_).sendSurplusGas(address(this));
    }

    function receiveSurplusGas() override external {

    }
}
