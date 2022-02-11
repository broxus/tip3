pragma ton-solidity >= 0.57.0;

import "../additional/TokenFactory.sol";


contract TestTokenFactory is TokenFactory {

    constructor(
        address owner,
        uint128 deployValue,
        TvmCell rootCode,
        TvmCell walletCode,
        TvmCell rootUpgradeableCode,
        TvmCell walletUpgradeableCode,
        TvmCell platformCode
    ) public TokenFactory(owner, deployValue, rootCode, walletCode, rootUpgradeableCode, walletUpgradeableCode, platformCode) {}

    function deployRootTest(
        string name,                    // static
        string symbol,                  // static
        uint8 decimals,                 // static
        address owner,                  // static
        address initialSupplyTo,        // constructor
        uint128 initialSupply,          // constructor
        uint128 deployWalletValue,      // constructor
        bool mintDisabled,              // constructor
        bool burnByRootDisabled,        // constructor
        bool burnPaused,                // constructor
        address remainingGasTo,         // constructor
        bool upgradeable
    ) external responsible returns (address) {
        tvm.accept();
        function (uint256, string, string, uint8, address) returns (TvmCell) buildStateInit =
            upgradeable ? _buildUpgradeableStateInit : _buildCommonStateInit;
        TvmCell stateInit = buildStateInit(_tokenNonce++, name, symbol, decimals, owner);
        address root = new TokenRoot {
            value: _deployValue,
            flag: TokenMsgFlag.SENDER_PAYS_FEES,
            bounce: false,
            stateInit: stateInit
        }(
            initialSupplyTo,
            initialSupply,
            deployWalletValue,
            mintDisabled,
            burnByRootDisabled,
            burnPaused,
            remainingGasTo
        );
        return {value: 0, flag: TokenMsgFlag.SENDER_PAYS_FEES, bounce: false} root;
    }

}
