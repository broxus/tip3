pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;

interface IBurnableByOwnerTokenWallet {
    function burnByOwner(
        uint128 tokens,
        uint128 grams,
        address send_gas_to,
        address callback_address,
        TvmCell callback_payload
    ) external;
}
