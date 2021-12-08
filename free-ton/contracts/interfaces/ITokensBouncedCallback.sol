pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;

interface ITokensBouncedCallback {
    function tokensBouncedCallback(
        address token_wallet,
        address token_root,
        uint128 amount,
        address bounced_from,
        uint128 updated_balance
    ) external;
}
