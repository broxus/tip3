pragma ton-solidity >= 0.56.0;

import "../additional/TokenFactory.sol";


contract TestTokenFactory is TokenFactory {

    constructor(
        address owner,
        uint128 deployValue,
        TvmCell rootCode,
        TvmCell walletCode
    ) public TokenFactory(owner, deployValue, rootCode, walletCode) {}

    function deployRootTest(
        string name,        // static
        string symbol,      // static
        uint8 decimals,     // static
        address owner,      // static
        address initialSupplyTo,
        uint128 initialSupply,
        uint128 deployWalletValue,
        bool mintDisabled,
        bool burnByRootDisabled,
        bool burnPaused,
        address remainingGasTo
    ) public responsible returns (address) {
        tvm.accept();
        TvmCell stateInit = _buildStateInit(_tokenNonce++, name, symbol, decimals, owner);
        return new TokenRoot {
            stateInit: stateInit,
            value: _deployValue,
            flag: 0,
            bounce: false
        }(
            initialSupplyTo,
            initialSupply,
            deployWalletValue,
            mintDisabled,
            burnByRootDisabled,
            burnPaused,
            remainingGasTo
        );
    }

}
