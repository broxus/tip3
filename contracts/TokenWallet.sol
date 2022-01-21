pragma ton-solidity >= 0.39.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/IDestroyable.sol";
import "./interfaces/TIP3TokenWallet.sol";
import "./interfaces/TIP3TokenRoot.sol";
import "./interfaces/ITokenWallet.sol";
import "./interfaces/ITokenRoot.sol";
import "./interfaces/IBurnableTokenWallet.sol";
import "./interfaces/IBurnableByRootTokenWallet.sol";
import "./interfaces/IBurnableTokenRoot.sol";
import "./interfaces/IAcceptTokensTransferCallback.sol";
import "./interfaces/IAcceptTokensMintCallback.sol";
import "./interfaces/IRevertTokensTransferCallback.sol";
import "./interfaces/IRevertTokensBurnCallback.sol";
import "./libraries/TokenErrors.sol";
import "./libraries/TokenGas.sol";
import "./interfaces/IVersioned.sol";
import "../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";


/*
    @title Fungible token wallet contract
*/
contract TokenWallet is ITokenWallet, IDestroyable, IBurnableTokenWallet, IBurnableByRootTokenWallet {

    address static root_;
    address static owner_;

    uint128 balance_;

    uint32 version_ = uint32(5);

    /*
        @notice Creates new token wallet
        @dev All the parameters are specified as initial data
    */
    constructor() public {
        require(tvm.pubkey() == 0, TokenErrors.NON_ZERO_PUBLIC_KEY);
        require(owner_.value != 0, TokenErrors.WRONG_WALLET_OWNER);
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

    function getDetails() override external view responsible returns (TokenWalletDetails) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } TokenWalletDetails(
            root_,
            owner_,
            balance_
        );
    }

    /*
        @notice Transfer tokens and optionally deploy TokenWallet for recipient
        @dev Can be called only by TokenWallet owner
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
            recipientWallet = new TokenWallet {
                stateInit: stateInit,
                value: deployWalletValue,
                wid: address(this).wid,
                flag: MsgFlag.SENDER_PAYS_FEES
            }();
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
        @dev Can be called only by token wallet owner
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

        TIP3TokenWallet(recipientTokenWallet).acceptTransfer{ value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: true }(
            amount,
            metaBuilder.toCell()
        );
    }

    /*
        @notice Callback for transfer operation
        @dev Can be called only by another valid TokenWallet contract with same root
        @param amount How much tokens to receive
        @param meta Additional data
    */
    function acceptTransfer(uint128 amount, TvmCell meta) override external {
        TvmSlice metaSlice = meta.toSlice();
        address sender = metaSlice.decode(address);
        require(msg.sender == address(tvm.hash(_buildWalletInitData(sender))), TokenErrors.SENDER_IS_NOT_VALID_WALLET);

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
        @notice Burn tokens
        @dev Can be called only by token wallet owner
        @param tokens How much tokens to burn
        @param grams How much EVERs attach to tokensBurned in case called with owner public key
        @param remainingGasTo Receiver of the remaining EVERs balance, used in tokensBurned callback
        @param callback_address Part of root tokensBurned callback data
        @param callback_payload Part of root tokensBurned callback data
    */
    function burn(uint128 amount, address remainingGasTo, address callbackTo, TvmCell payload)
        override
        external
        onlyOwner
    {
        _burn(amount, remainingGasTo, callbackTo, payload, _reserve());
    }

    /*
        @notice Burn tokens in case it's initiated by the root and execute callback
        @dev Can be called only by root token wallet
        @param tokens How much tokens to burn
        @param remainingGasTo Part of root callback data
        @param callbackTo Part of root callback data
        @param payload Part of root callback data
    */
    function burnByRoot(uint128 amount, address remainingGasTo, address callbackTo, TvmCell payload)
        override
        external
        onlyRoot
    {
        _burn(amount, remainingGasTo, callbackTo, payload, address(this).balance - msg.value);
    }

    function destroy(address remainingGasTo) override external onlyOwner {
        require(balance_ == 0, TokenErrors.NON_EMPTY_BALANCE);
        remainingGasTo.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.DESTROY_IF_ZERO, bounce: false });
    }

    // =============== Support functions ==================

    modifier onlyRoot() {
        require(root_ == msg.sender, TokenErrors.NOT_ROOT);
        _;
    }

    modifier onlyOwner() {
        require(owner_ == msg.sender, TokenErrors.NOT_OWNER);
        _;
    }

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
            contr: TokenWallet,
            varInit: {
                root_: root_,
                owner_: walletOwner
            },
            pubkey: 0,
            code: tvm.code()
        });
    }

    /*
        @notice On-bounce handler
        @dev Catch bounce if acceptTransfer or tokensBurned fails
        @dev If transfer fails - increase back tokens balance and notify owner
        @dev If tokens burn root token callback fails - increase back tokens balance and notify owner
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
}
