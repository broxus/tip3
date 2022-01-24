pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./TokenWallet.sol";
import "./abstract/TokenRootBurnableByRootBase.sol";
import "./libraries/TokenErrors.sol";
import "./libraries/TokenMsgFlag.sol";


/*
    @title Fungible token  root contract
*/
contract TokenRoot is TokenRootBurnableByRootBase {

    uint256 static randomNonce_;
    address static deployer_;

    constructor(
        address initialSupplyTo,
        uint128 initialSupply,
        uint128 deployWalletValue,
        bool mintDisabled,
        bool burnByRootDisabled,
        bool burnPaused,
        address remainingGasTo
    )
        public
    {
        if (msg.pubkey() != 0) {
            require(msg.pubkey() == tvm.pubkey() && deployer_.value == 0, TokenErrors.WRONG_ROOT_OWNER);
            tvm.accept();
        } else {
            require(deployer_.value != 0 && msg.sender == deployer_ ||
                    deployer_.value == 0 && msg.sender == rootOwner_, TokenErrors.WRONG_ROOT_OWNER);
        }

        totalSupply_ = 0;
        mintDisabled_ = mintDisabled;
        burnByRootDisabled_ = burnByRootDisabled;
        burnPaused_ = burnPaused;

        tvm.rawReserve(TokenGas.TARGET_ROOT_BALANCE, 0);

        if (initialSupplyTo.value != 0 && initialSupply != 0) {
            TvmCell empty;
            _mint(initialSupply, initialSupplyTo, deployWalletValue, remainingGasTo, false, empty);
        } else if (remainingGasTo.value != 0) {
            remainingGasTo.transfer({
                value: 0,
                flag: TokenMsgFlag.ALL_NOT_RESERVED + TokenMsgFlag.IGNORE_ERRORS,
                bounce: false
            });
        }
    }

    function supportsInterface(bytes4 interfaceID) override external view responsible returns(bool) {
        return { value: 0, flag: TokenMsgFlag.REMAINING_GAS, bounce: false } (
            interfaceID == bytes4(0x4371D8ED)
        );
    }

    function _reserve() override internal pure returns(uint128) {
        return math.max(address(this).balance - msg.value, TokenGas.TARGET_ROOT_BALANCE);
    }

    function _buildWalletInitData(address walletOwner) override internal view returns(TvmCell) {
        return tvm.buildStateInit({
            contr: TokenWallet,
            varInit: {
                root_: address(this),
                owner_: walletOwner
            },
            pubkey: 0,
            code: walletCode_
        });
    }

    function _deployWallet(TvmCell initData, uint128 deployWalletValue, address)
        override
        internal
        view
        returns(address)
    {
       address tokenWallet = new TokenWallet {
            stateInit: initData,
            value: deployWalletValue,
            flag: TokenMsgFlag.SENDER_PAYS_FEES,
            code: walletCode_
        }();
        return tokenWallet;
    }

}
