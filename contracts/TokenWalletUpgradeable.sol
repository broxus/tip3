pragma ton-solidity >= 0.39.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./abstract/TokenWalletBurnableByRootBase.sol";
import "./interfaces/ITokenWalletUpgradeable.sol";
import "./interfaces/ITokenRootUpgradeable.sol";
import "./interfaces/IVersioned.sol";
import "./libraries/TokenErrors.sol";
import "./libraries/TokenGas.sol";
import "./libraries/TokenMsgFlag.sol";
import "./TokenWalletPlatform.sol";


/*
    @title Fungible token wallet contract
*/
contract TokenWalletUpgradeable is TokenWalletBurnableByRootBase, ITokenWalletUpgradeable {

    uint32 version_;
    TvmCell platformCode_;

    constructor() public {
        revert();
    }

    function platformCode() override external view responsible returns(TvmCell) {
        return { value: 0, flag: TokenMsgFlag.REMAINING_GAS, bounce: false } platformCode_;
    }

    function supportsInterface(bytes4 interfaceID) override external view responsible returns(bool) {
        return { value: 0, flag: TokenMsgFlag.REMAINING_GAS, bounce: false } (
            interfaceID == 0x4F479FA3
        );
    }

    /*
        0x15A038FB is TokenWalletPlatform constructor functionID
    */
    function onDeployRetry(TvmCell, uint32, address sender, address remainingGasTo)
        external
        view
        functionID(0x15A038FB)
    {
        require(msg.sender == root_ || address(tvm.hash(_buildWalletInitData(sender))) == msg.sender);

        tvm.rawReserve(_reserve(), 0);

        if (remainingGasTo.value != 0 && remainingGasTo != address(this)) {
            remainingGasTo.transfer({
                value: 0,
                flag: TokenMsgFlag.ALL_NOT_RESERVED + TokenMsgFlag.IGNORE_ERRORS,
                bounce: false
            });
        }
    }

    function version() override external view responsible returns(uint32) {
        return { value: 0, flag: TokenMsgFlag.REMAINING_GAS, bounce: false } version_;
    }

    function upgrade(address remainingGasTo) override external onlyOwner {
        ITokenRootUpgradeable(root_).requestUpgradeWallet{ value: 0, flag: TokenMsgFlag.REMAINING_GAS, bounce: false }(
            version_,
            owner_,
            remainingGasTo
        );
    }

    function acceptUpgrade(TvmCell newCode, uint32 newVersion, address remainingGasTo) override external onlyRoot {
        tvm.rawReserve(_reserve(), 0);
        if (version_ == newVersion) {
            remainingGasTo.transfer({
                value: 0,
                flag: TokenMsgFlag.ALL_NOT_RESERVED + TokenMsgFlag.IGNORE_ERRORS,
                bounce: false
            });
        } else {
            TvmBuilder builder;

            builder.store(root_);
            builder.store(owner_);
            builder.store(balance_);
            builder.store(version_);
            builder.store(newVersion);
            builder.store(remainingGasTo);

            builder.store(platformCode_);

            tvm.setcode(newCode);
            tvm.setCurrentCode(newCode);
            onCodeUpgrade(builder.toCell());
        }
    }

    function onCodeUpgrade(TvmCell data) private {
        tvm.resetStorage();

        uint32 oldVersion;
        address remainingGasTo;

        TvmSlice s = data.toSlice();
        (root_, owner_, balance_, oldVersion, version_, remainingGasTo) = s.decode(
            address,
            address,
            uint128,
            uint32,
            uint32,
            address
        );

        platformCode_ = s.loadRef();

        if (remainingGasTo.value != 0 && remainingGasTo != address(this)) {
            remainingGasTo.transfer({
                value: 0,
                flag: TokenMsgFlag.ALL_NOT_RESERVED + TokenMsgFlag.IGNORE_ERRORS,
                bounce: false
            });
        }
    }

    function _reserve() override internal pure returns(uint128) {
        return math.max(address(this).balance - msg.value, TokenGas.TARGET_WALLET_BALANCE);
    }

    function _buildWalletInitData(address walletOwner) override internal view returns(TvmCell) {
        return tvm.buildStateInit({
            contr: TokenWalletPlatform,
            varInit: {
                root: root_,
                owner: walletOwner
            },
            pubkey: 0,
            code: platformCode_
        });
    }

    function _deployWallet(
        TvmCell initData,
        uint128 deployWalletValue,
        address remainingGasTo
    )
        override
        internal
        view
        returns(address)
    {
        address wallet = new TokenWalletPlatform {
            stateInit: initData,
            value: deployWalletValue,
            wid: address(this).wid,
            flag: TokenMsgFlag.SENDER_PAYS_FEES
        }(tvm.code(), version_, owner_, remainingGasTo);
        return wallet;
    }
}
