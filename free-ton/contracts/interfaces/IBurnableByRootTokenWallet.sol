pragma ton-solidity ^0.38.2;
pragma AbiHeader expire;

interface IBurnableByRootTokenWallet {
    function burnByRoot(
        uint128 tokens,
        address send_gas_to,
        address callback_address,
        TvmCell callback_payload
    ) external;
}
