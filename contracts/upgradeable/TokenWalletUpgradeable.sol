pragma ton-solidity >= 0.39.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../interfaces/IDestroyable.sol";
import "../interfaces/ITokenWalletUpgradeable.sol";
import "../interfaces/ITokenRootUpgradeable.sol";
import "../interfaces/IBurnableTokenWallet.sol";
import "../interfaces/IBurnableByRootTokenWallet.sol";
import "../interfaces/IBurnableTokenRoot.sol";
import "../interfaces/IAcceptTokensTransferCallback.sol";
import "../interfaces/IAcceptTokensMintCallback.sol";
import "../interfaces/IRevertTokensTransferCallback.sol";
import "../interfaces/IRevertTokensBurnCallback.sol";
import "../interfaces/TIP3TokenWallet.sol";
import "../interfaces/TIP3TokenRoot.sol";
import "../libraries/TokenErrors.sol";
import "../libraries/TokenGas.sol";
import "../interfaces/IVersioned.sol";
import "../../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";
import "./TokenWalletPlatform.sol";


/*
    @title Fungible token wallet contract
*/
contract TokenWalletUpgradeable is ITokenWalletUpgradeable, IDestroyable, IBurnableTokenWallet, IBurnableByRootTokenWallet, IVersioned {

    address root_;
    address owner_;

    uint128 balance_;

    uint32 version_;
    TvmCell platformCode_;

    constructor() public {
        revert();
    }

    fallback() external {
    }

    // TODO
    function supportsInterface(bytes4 interfaceID) override external view responsible returns (bool) {
        bytes4 tip3TokenWallet = bytes4(
            tvm.functionId(TIP3TokenWallet.root) ^
            tvm.functionId(TIP3TokenWallet.balance) ^
            tvm.functionId(TIP3TokenWallet.walletCode) ^
            tvm.functionId(TIP3TokenWallet.acceptTransfer) ^
            tvm.functionId(TIP3TokenWallet.acceptMint)
        );

        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } (
            interfaceID == tip3TokenWallet
        );
    }

    /* Modifiers */

    modifier onlyRoot() {
        require(root_ == msg.sender, TokenErrors.NOT_ROOT);
        _;
    }

    modifier onlyOwner() {
        require(owner_ == msg.sender, TokenErrors.NOT_OWNER);
        _;
    }

    /* Getters */

    function version() override external view responsible returns (uint32) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } version_;
    }

    function balance() override external view responsible returns (uint128) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } balance_;
    }

    function owner() override external view responsible returns (address) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } owner_;
    }

    function root() override external view responsible returns (address) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } root_;
    }

    function walletCode() override external view responsible returns (TvmCell) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } tvm.code();
    }

    function platformCode() override external view responsible returns (TvmCell) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } platformCode_;
    }

    function getDetails() override external view responsible returns (TokenWalletDetails) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } TokenWalletDetails(
            root_,
            owner_,
            balance_
        );
    }

    /* Owned methods */

    /*
        @notice Transfer tokens and optionally deploy TokenWallet for recipient
        @dev Can be called only by TokenWallet owner_
        @dev If deployWalletValue !=0 deploy token wallet for recipient using that gas value
        @param amount How much tokens to transfer
        @param recipient Tokens recipient
        @param deployWalletValue How much EVERs to attach to token wallet deploy
        @param remainingGasTo Remaining gas receiver
        @param notify Notify receiver on incoming transfer
        @param payload Notification payload
    */
    function transfer(
        uint128 amount,
        address recipient,
        uint128 deployWalletValue,
        address remainingGasTo,
        bool notify,
        TvmCell payload
    )
        override
        external
        onlyOwner
    {
        require(amount > 0, TokenErrors.WRONG_AMOUNT);
        require(amount <= balance_, TokenErrors.NOT_ENOUGH_BALANCE);
        require(recipient.value != 0 && recipient != owner_, TokenErrors.WRONG_RECIPIENT);

        tvm.rawReserve(_reserve(), 0);

        TvmCell stateInit = _buildWalletInitData(recipient);

        address recipientWallet;

        if (deployWalletValue > 0) {
            recipientWallet = new TokenWalletPlatform {
                stateInit: stateInit,
                value: deployWalletValue,
                wid: address(this).wid,
                flag: MsgFlag.SENDER_PAYS_FEES
            }(tvm.code(), version_, owner_, remainingGasTo);
        } else {
            recipientWallet = address(tvm.hash(stateInit));
        }

        balance_ -= amount;

        TvmBuilder metaBuilder;
        metaBuilder.store(owner_);
        metaBuilder.store(remainingGasTo);
        metaBuilder.store(notify);
        metaBuilder.store(payload);

        TIP3TokenWallet(recipientWallet).acceptTransfer{ value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: true }(
            amount,
            metaBuilder.toCell()
        );
    }

    /*
        @notice Transfer tokens using another TokenWallet address, that wallet must be deployed previously
        @dev Can be called only by token wallet owner_
        @param amount How much tokens to transfer
        @param recipientWallet Recipient TokenWallet address
        @param remainingGasTo Remaining gas receiver
        @param notify Notify receiver on incoming transfer
        @param payload Notification payload
    */
    function transferToWallet(
        uint128 amount,
        address recipientTokenWallet,
        address remainingGasTo,
        bool notify,
        TvmCell payload
    )
        override
        external
        onlyOwner
    {
        require(amount > 0, TokenErrors.WRONG_AMOUNT);
        require(amount <= balance_, TokenErrors.NOT_ENOUGH_BALANCE);
        require(recipientTokenWallet.value != 0 && recipientTokenWallet != address(this), TokenErrors.WRONG_RECIPIENT);

        tvm.rawReserve(_reserve(), 0);

        balance_ -= amount;

        TvmBuilder metaBuilder;
        metaBuilder.store(owner_);
        metaBuilder.store(remainingGasTo);
        metaBuilder.store(notify);
        metaBuilder.store(payload);

        ITokenWallet(recipientTokenWallet).acceptTransfer{ value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: true }(
            amount,
            metaBuilder.toCell()
        );
    }

    /*
        @notice Burn tokens
        @dev Can be called only by token wallet owner_
        @param tokens How much tokens to burn
        @param grams How much EVERs attach to tokensBurned in case called with owner_ public key
        @param remainingGasTo Receiver of the remaining EVERs balance_, used in tokensBurned callback
        @param callbackTo Part of root_ acceptBurn callback data
        @param payload Part of root_ acceptBurn callback data
    */
    function burn(uint128 amount, address remainingGasTo, address callbackTo, TvmCell payload)
        override
        external
        onlyOwner
    {
        _burn(amount, remainingGasTo, callbackTo, payload, _reserve());
    }


    /* Internal methods */

    /*
        @notice Callback for transfer operation
        @dev Can be called only by another valid TokenWallet contract with same root_
        @param amount How much tokens to receive
        @param sender Sender TokenWallet owner_ address
        @param remainingGasTo Remaining gas receiver
        @param notify Notify receiver on incoming transfer
        @param payload Notification payload
    */
    function acceptTransfer(uint128 amount, TvmCell meta) override external {
        TvmSlice metaSlice = meta.toSlice();
        address sender = metaSlice.decode(address);
        require(msg.sender == address(tvm.hash(_buildWalletInitData(sender))), TokenErrors.SENDER_IS_NOT_VALID_WALLET);
        require(sender != owner_, TokenErrors.WRONG_RECIPIENT);

        tvm.rawReserve(_reserve(), 2);

        address remainingGasTo = metaSlice.decode(address);
        bool notify = metaSlice.decode(bool);

        balance_ += amount;

        if (notify) {
            TvmCell payload = metaSlice.loadRef();
            IAcceptTokensTransferCallback(owner_).onAcceptTokensTransfer{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS,
                bounce: false
            }(
                root_,
                amount,
                sender,
                msg.sender,
                remainingGasTo,
                payload
            );
        } else {
            remainingGasTo.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS, bounce: false });
        }
    }

    /*
        @notice Accept minted tokens from root
        @dev Can be called only by root token
        @param amount How much tokens to accept
        @param data Additional data
    */
    function acceptMint(uint128 amount, TvmCell meta)
        override
        external
        onlyRoot
    {
        tvm.rawReserve(_reserve(), 2);

        TvmSlice metaSlice = meta.toSlice();
        address remainingGasTo = metaSlice.decode(address);
        bool notify = metaSlice.decode(bool);

        balance_ += amount;

        if (notify) {
            TvmCell payload = metaSlice.loadRef();
            IAcceptTokensMintCallback(owner_).onAcceptTokensMint{
                value: 0,
                bounce: false,
                flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
            }(
                root_,
                amount,
                remainingGasTo,
                payload
            );
        } else if (remainingGasTo.value != 0 && remainingGasTo != address(this)) {
            remainingGasTo.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS, bounce: false });
        }
    }

    /*
        @notice Burn tokens in case it's initiated by the root_ and execute callback
        @dev Can be called only by root_ token wallet
        @param tokens How much tokens to burn
        @param remainingGasTo Part of root_ callback data
        @param callbackTo Part of root_ callback data
        @param payload Part of root_ callback data
    */
    function burnByRoot(uint128 amount, address remainingGasTo, address callbackTo, TvmCell payload)
        override
        external
        onlyRoot
    {
        _burn(amount, remainingGasTo, callbackTo, payload, address(this).balance - msg.value);
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
            remainingGasTo.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS, bounce: false });
        }
    }

    /*
        @notice Destroy token wallet and withdraw EVERs balance_
        @dev Requires 0 token balance_
        @param gas_dest EVERs receiver
    */
    function destroy(address remainingGasTo) override external onlyOwner {
        require(balance_ == 0, TokenErrors.NON_EMPTY_BALANCE);
        remainingGasTo.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.DESTROY_IF_ZERO, bounce: false });
    }

    function upgrade(address remainingGasTo) override external onlyOwner {
        ITokenRootUpgradeable(root_).requestUpgradeWallet{ value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false }(
            version_,
            owner_,
            remainingGasTo
        );
    }

    function acceptUpgrade(TvmCell newCode, uint32 newVersion, address remainingGasTo) override external onlyRoot {
        tvm.rawReserve(_reserve(), 0);
        if (version_ == newVersion) {
            remainingGasTo.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS, bounce: false });
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

    /*
        @notice On-bounce handler
        @dev Catch bounce if acceptTransfer or tokensBurned fails
        @dev If transfer fails - increase back tokens balance_ and notify callback_
        @dev If tokens burn root_ token callback fails - increase back tokens balance_
        @dev Withdraws gas to owner_ by default if internal owner_ship is used
        @dev Or sends gas to bounce_callback if it's enabled
    */
    onBounce(TvmSlice body) external {

        tvm.rawReserve(_reserve(), 2);

        uint32 functionId = body.decode(uint32);

        if (functionId == tvm.functionId(TIP3TokenWallet.acceptTransfer)) {
            uint128 amount = body.decode(uint128);
            balance_ += amount;
            IRevertTokensTransferCallback(owner_).onRevertTokensTransfer{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS,
                bounce: false
            }(
                root_,
                amount,
                msg.sender
            );
        } else if (functionId == tvm.functionId(TIP3TokenRoot.acceptBurn)) {
            uint128 amount = body.decode(uint128);
            balance_ += amount;
            IRevertTokensBurnCallback(owner_).onRevertTokensBurn{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS,
                bounce: false
            }(
                root_,
                amount
            );
        }
    }

    // =============== Private functions ==================

    function _reserve() internal pure returns (uint128) {
        return math.max(address(this).balance - msg.value, TokenGas.TARGET_WALLET_BALANCE);
    }

    function _burn(
        uint128 amount,
        address remainingGasTo,
        address callbackTo,
        TvmCell payload,
        uint128 reserve
    ) internal {
        require(amount > 0, TokenErrors.WRONG_AMOUNT);
        require(amount <= balance_, TokenErrors.NOT_ENOUGH_BALANCE);

        tvm.rawReserve(reserve, 0);

        balance_ -= amount;

        TvmBuilder metaBuilder;
        metaBuilder.store(owner_);
        metaBuilder.store(remainingGasTo);
        metaBuilder.store(callbackTo);
        metaBuilder.store(payload);

        TIP3TokenRoot(root_).acceptBurn{ value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: true }(
            amount,
            metaBuilder.toCell()
        );
    }

    function _buildWalletInitData(address walletOwner) internal view returns (TvmCell) {
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
                flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS,
                bounce: false
            });
        }
    }
}
