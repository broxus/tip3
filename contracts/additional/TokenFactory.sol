pragma ton-solidity >= 0.57.0;

import "../TokenRoot.sol";
import "./TokenFactoryBase.sol";


contract TokenFactory is TokenFactoryBase {

    constructor(
        address owner,
        uint128 deployValue,
        TvmCell rootCode,
        TvmCell walletCode
    ) public TokenFactoryBase(owner, deployValue, rootCode, walletCode) {}


    function deployRoot(
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
    ) public responsible override returns (address) {
        tvm.rawReserve(address(this).balance - msg.value, 0);
        TvmCell stateInit = _buildStateInit(_tokenNonce++, name, symbol, decimals, owner);
        address root = new TokenRoot {
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
        return {value: 0, flag: TokenMsgFlag.REMAINING_GAS, bounce: false} root;
    }

    function _buildStateInit(
        uint256 nonce,
        string name,
        string symbol,
        uint8 decimals,
        address owner
    ) internal view override returns (TvmCell) {
        return tvm.buildStateInit({
            contr: TokenRoot,
            varInit: {
                randomNonce_: nonce,
                deployer_: address(this),
                name_: name,
                symbol_: symbol,
                decimals_: decimals,
                rootOwner_: owner,
                walletCode_: _walletCode
            },
            code: _rootCode,
            pubkey: 0
        });
    }

    function upgrade(TvmCell code) public override onlyOwner {
        TvmBuilder builder;
        builder.store(_owner);
        builder.store(_pendingOwner);
        builder.store(_tokenNonce);
        builder.store(_rootCode);
        builder.store(_walletCode);

        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(builder.toCell());
    }

    function onCodeUpgrade(TvmCell data) private {
        tvm.resetStorage();
        TvmSlice slice = data.toSlice();
        (_owner, _pendingOwner, _tokenNonce) = slice.decode(address, address, uint256);
        _rootCode = slice.loadRef();
        _walletCode = slice.loadRef();
    }

}
