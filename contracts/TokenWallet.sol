pragma ton-solidity >= 0.39.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/IDestroyable.sol";
import "./interfaces/ITokenWallet.sol";
import "./interfaces/ITokenRoot.sol";
import "./interfaces/IBurnableTokenWallet.sol";
import "./interfaces/IBurnableByRootTokenWallet.sol";
import "./interfaces/IBurnableTokenRoot.sol";
import "./interfaces/IAcceptMintedTokensCallback.sol";
import "./interfaces/ITokenBurnRevertedCallback.sol";
import "./interfaces/ITokenWalletCallback.sol";
import "./libraries/TokenErrors.sol";
import "./libraries/TokenGas.sol";
import "./interfaces/IVersioned.sol";
import "../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";


/*
    @title Fungible token wallet contract
*/
contract TokenWallet is ITokenWallet, IDestroyable, IBurnableTokenWallet, IBurnableByRootTokenWallet, IVersioned {

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

    /*
        @notice Get details about token wallet
        @returns root Token root address
        @returns owner Token wallet owner address
        @returns balance Token wallet balance in tokens
    */
    function getDetails() override external view responsible returns (TokenWalletDetails) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } TokenWalletDetails(
            root_,
            owner_,
            balance_
        );
    }

    /*
        @notice Accept minted tokens from root
        @dev Can be called only by root token
        @param amount How much tokens to accept
        @param remainingGasTo Remaining gas receiver
        @param notify Notify receiver on incoming mint
        @param payload Notification payload
    */
    function acceptMinted(uint128 amount, address remainingGasTo, bool notify, TvmCell payload)
        override
        external
        onlyRoot
    {
        balance_ += amount;

        _reserve();

        if (notify) {
            IAcceptMintedTokensCallback(owner_).onAcceptMintedTokens{
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

        _reserve();

        TvmCell stateInit = tvm.buildStateInit({
            contr: TokenWallet,
            varInit: {
                root_: root_,
                owner_: recipient
            },
            pubkey: 0,
            code: tvm.code()
        });

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
        
        ITokenWallet(recipientWallet).internalTransfer{ value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: true }(
            amount,
            owner_,
            remainingGasTo,
            notify,
            payload
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

        _reserve();

        balance_ -= amount;

        ITokenWallet(recipientTokenWallet).internalTransfer{ value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: true }(
            amount,
            owner_,
            remainingGasTo,
            notify,
            payload
        );
    }

    /*
        @notice Callback for transfer operation
        @dev Can be called only by another valid TokenWallet contract with same root
        @param amount How much tokens to receive
        @param sender Sender TokenWallet owner address
        @param remainingGasTo Remaining gas receiver
        @param payload Notification payload
    */
    function internalTransfer(uint128 amount, address sender, address remainingGasTo, bool notify, TvmCell payload)
        override
        external
    {
        address expectedSenderWallet = _getExpectedAddress(sender);
        require(msg.sender == expectedSenderWallet, TokenErrors.SENDER_IS_NOT_VALID_WALLET);
        require(sender != owner_, TokenErrors.WRONG_RECIPIENT);

        balance_ += amount;

        _reserve();

        if (notify) {
            ITokenWalletCallback(owner_).onTokenTransferReceived{
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
        require(amount > 0, TokenErrors.WRONG_AMOUNT);
        require(amount <= balance_, TokenErrors.NOT_ENOUGH_BALANCE);

        _reserve();

        balance_ -= amount;

        IBurnableTokenRoot(root_).tokensBurned{ value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: true }(
            amount,
            owner_,
            remainingGasTo,
            callbackTo,
            payload
        );
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
        require(amount > 0, TokenErrors.WRONG_AMOUNT);
        require(amount <= balance_, TokenErrors.NOT_ENOUGH_BALANCE);

        balance_ -= amount;

        IBurnableTokenRoot(root_).tokensBurned{ value: 0, flag: MsgFlag.REMAINING_GAS, bounce: true }(
            amount,
            owner_,
            remainingGasTo,
            callbackTo,
            payload
        );
    }

    /*
        @notice Destroy token wallet and withdraw EVERs balance
        @dev Requires 0 token balance
        @param gas_dest EVERs receiver
    */
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

    function _reserve() private view inline {
        tvm.rawReserve(math.max(TokenGas.TARGET_WALLET_BALANCE, address(this).balance - msg.value), 0);
    }

    /*
        @notice Derive token wallet contract address from owner credentials
        @param wallet_public_key_ Token wallet owner public key
        @param owner_ Token wallet owner address
    */
    function _getExpectedAddress(address walletOwner) private view returns (address) {
        TvmCell stateInit = tvm.buildStateInit({
            contr: TokenWallet,
            varInit: {
                root_: root_,
                owner_: walletOwner
            },
            pubkey: 0,
            code: tvm.code()
        });

        return address(tvm.hash(stateInit));
    }

    /*
        @notice On-bounce handler
        @dev Catch bounce if internalTransfer or tokensBurned fails
        @dev If transfer fails - increase back tokens balance and notify owner
        @dev If tokens burn root token callback fails - increase back tokens balance and notify owner
    */
    onBounce(TvmSlice body) external {
        uint32 functionId = body.decode(uint32);

        if (functionId == tvm.functionId(ITokenWallet.internalTransfer)) {
            uint128 amount = body.decode(uint128);
            balance_ += amount;
            _reserve();
            ITokenWalletCallback(owner_).onTokenTransferReverted{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS,
                bounce: false
            }(
                root_,
                amount,
                msg.sender
            );
        } else if (functionId == tvm.functionId(IBurnableTokenRoot.tokensBurned)) {
            uint128 amount = body.decode(uint128);
            balance_ += amount;
            _reserve();
            ITokenBurnRevertedCallback(owner_).onTokenBurnReverted{
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
