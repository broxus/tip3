pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;

import "./AllowanceInfoStructure.sol";

interface ITONTokenWallet is AllowanceInfoStructure {

    struct ITONTokenWalletDetails {
        address root_address;
        uint256 wallet_public_key;
        address owner_address;
        uint128 balance;

        address receive_callback;
        address bounced_callback;
        bool allow_non_notifiable;
    }

    function getDetails() external view responsible returns (ITONTokenWalletDetails);

    function getWalletCode() external view responsible returns (TvmCell);

    function accept(uint128 tokens) external;

    function balance() external view responsible returns (uint128);
    function allowance() external view responsible returns (AllowanceInfo);
    function approve(address spender, uint128 remaining_tokens, uint128 tokens) external;
    function disapprove() external;

    function setReceiveCallback(address receive_callback, bool allow_non_notifiable) external;
    function setBouncedCallback(address bounced_callback) external;

    function transfer(
        address to,
        uint128 tokens,
        uint128 grams,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    ) external;

    function transferFrom(
        address from,
        address to,
        uint128 tokens,
        uint128 grams,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    ) external;

    function transferToRecipient(
        uint256 recipient_public_key,
        address recipient_address,
        uint128 tokens,
        uint128 deploy_grams,
        uint128 transfer_grams,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    ) external;

    function internalTransfer(
        uint128 tokens,
        uint256 sender_public_key,
        address sender_address,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    ) external;

    function internalTransferFrom(
        address to,
        uint128 tokens,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    ) external;

}
