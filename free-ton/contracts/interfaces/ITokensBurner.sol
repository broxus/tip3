pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;

interface ITokensBurner {
    function burnMyTokens(
        uint128 tokens,
        address send_gas_to,
        address callback_address,
        TvmCell callback_payload
    ) external;
}
