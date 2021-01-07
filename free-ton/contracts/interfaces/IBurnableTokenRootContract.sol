pragma solidity >= 0.6.0;
pragma AbiHeader expire;

interface IBurnableTokenRootContract {
    function tokensBurned(
        uint128 tokens,
        uint256 sender_public_key,
        address sender_address,
        address callback_address,
        TvmCell callback_payload) external;
}
