pragma ton-solidity >= 0.39.0;

interface TIP3TokenRoot {
    function name() external view responsible returns (string);
    function symbol() external view responsible returns (string);
    function decimals() external view responsible returns (uint8);
    function totalSupply() external view responsible returns (uint128);
    function walletCode() external view responsible returns (TvmCell);

    function acceptBurn(
        uint128 _value,
        TvmCell _meta
    ) external;

}
