pragma solidity >= 0.6.0;
pragma AbiHeader expire;

interface ITONTokenWalletWithNotifiableTransfers {

    function setReceiveCallback(address receive_callback_) external;

    function transferWithNotify(
        address to,
        uint128 tokens,
        uint128 grams,
        bool notify_receiver,
        TvmCell payload
    ) external;

    function transferFromWithNotify(
        address from,
        address to,
        uint128 tokens,
        uint128 grams,
        bool notify_receiver,
        TvmCell payload
    ) external;

    function transferToRecipientWithNotify(
        uint256 recipient_public_key,
        address recipient_address,
        uint128 tokens,
        uint128 deploy_grams,
        uint128 transfer_grams,
        bool notify_receiver,
        TvmCell payload
    ) external;
}
