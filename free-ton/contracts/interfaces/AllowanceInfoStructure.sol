pragma solidity >= 0.6.0;
pragma AbiHeader expire;


interface AllowanceInfoStructure {
    struct AllowanceInfo {
        uint128 remaining_tokens;
        address spender;
    }
}
