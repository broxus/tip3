pragma ton-solidity >= 0.39.0;

interface TIP3TokenWallet {
    function root() external view responsible returns (address);
    function balance() external view responsible returns (uint128);
    function walletCode() external view responsible returns (TvmCell);

    function acceptTransfer(
        uint128 _value,
        TvmCell _meta
    ) external;

    function acceptMint(
        uint128 _value,
        TvmCell _meta
    ) external;
}
