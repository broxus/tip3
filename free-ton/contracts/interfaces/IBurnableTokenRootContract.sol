pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;

interface IBurnableTokenRootContract {
    function tokensBurned(
        uint128 tokens,
        uint256 sender_public_key,
        address sender_address,
        address send_gas_to,
        address callback_address,
        TvmCell callback_payload) external;
}
