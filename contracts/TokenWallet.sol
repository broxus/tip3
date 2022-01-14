pragma ton-solidity >= 0.39.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/IDestroyable.sol";
import "./interfaces/ITokenWallet.sol";
import "./interfaces/ITokenRoot.sol";
import "./interfaces/IBurnableTokenWallet.sol";
import "./interfaces/IBurnableByRootTokenWallet.sol";
import "./interfaces/IBurnableTokenRoot.sol";
import "./interfaces/ITokenWalletDeployedCallback.sol";
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

    address static root;
    address static owner;

    uint128 balance;
    address callback_;
    bool onlyNotifiableTransfers_;

    uint32 version = uint32(5);

    /*
        @notice Creates new token wallet
        @dev All the parameters are specified as initial data
        @dev Owner will be notified with .notifyWalletDeployed
    */
    constructor() public {
        require(tvm.pubkey() == 0, TokenErrors.NON_ZERO_PUBLIC_KEY);
        require(owner.value != 0, TokenErrors.WRONG_WALLET_OWNER);

        onlyNotifiableTransfers_ = false;
    }

    fallback() external {
    }

    function requestDeployedCallback(address callbackTo) external view onlyRoot {
        ITokenRoot(root).proxyDeployedCallback{
            value: 0,
            bounce: false,
            flag: MsgFlag.REMAINING_GAS
        }(owner, callbackTo, version);
    }

    function getVersion() override external view responsible returns (uint32) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } version;
    }

    function getBalance() override external view responsible returns (uint128) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } balance;
    }

    function getOwner() override external view responsible returns (address) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } owner;
    }

    function getWalletCode() override external view responsible returns (TvmCell) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } tvm.code();
    }

    /*
        @notice Get details about token wallet
        @returns root Token root address
        @returns owner Token wallet owner address
        @returns balance Token wallet balance in tokens
        @returns callback_ Receive callback contract
        @return onlyNotifiableTransfers Wallet don't receive transfers without notify
    */
    function getDetails() override external view responsible returns (TokenWalletDetails) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } TokenWalletDetails(
            root,
            owner,
            balance,
            callback_,
            onlyNotifiableTransfers_
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
        _reserve();

        balance += amount;

        if (notify && callback_.value != 0) {
            IAcceptMintedTokensCallback(callback_).onAcceptMintedTokens{
                value: 0,
                bounce: false,
                flag: MsgFlag.ALL_NOT_RESERVED
            }(
                address(this),
                root,
                amount,
                remainingGasTo,
                payload
            );
        } else if (remainingGasTo.value != 0) {
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
        require(amount <= balance, TokenErrors.NOT_ENOUGH_BALANCE);
        require(recipient.value != 0 && recipient != owner, TokenErrors.WRONG_RECIPIENT);
        require(deployWalletValue >= TokenGas.WALLET_DEPLOY_MIN_VALUE || deployWalletValue == 0,
            TokenErrors.DEPLOY_WALLET_VALUE_TOO_LOW);
        uint128 reserve = math.max(TokenGas.TARGET_WALLET_BALANCE, address(this).balance - msg.value);
        require(address(this).balance > reserve + TokenGas.TARGET_WALLET_BALANCE + deployWalletValue,
            TokenErrors.LOW_GAS_VALUE);

        tvm.rawReserve(reserve, 0);

        TvmCell stateInit = tvm.buildStateInit({
            contr: TokenWallet,
            varInit: {
                root: root,
                owner: recipient
            },
            pubkey: 0,
            code: tvm.code()
        });

        address recipientWallet;

        if(deployWalletValue > 0) {
            recipientWallet = new TokenWallet {
                stateInit: stateInit,
                value: deployWalletValue,
                wid: address(this).wid,
                flag: MsgFlag.SENDER_PAYS_FEES
            }();
        } else {
            recipientWallet = address(tvm.hash(stateInit));
        }
            
        balance -= amount;
        
        ITokenWallet(recipientWallet).internalTransfer{ value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: true }(
            amount,
            owner,
            remainingGasTo.value != 0 ? remainingGasTo : owner,
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
        require(amount <= balance, TokenErrors.NOT_ENOUGH_BALANCE);
        require(recipientTokenWallet.value != 0 && recipientTokenWallet != address(this), TokenErrors.WRONG_RECIPIENT);
        uint128 reserve = math.max(TokenGas.TARGET_WALLET_BALANCE, address(this).balance - msg.value);
        require(address(this).balance > reserve + TokenGas.TARGET_WALLET_BALANCE, TokenErrors.LOW_GAS_VALUE);
        tvm.rawReserve(reserve, 0);

        balance -= amount;

        ITokenWallet(recipientTokenWallet).internalTransfer{ value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: true }(
            amount,
            owner,
            remainingGasTo.value != 0 ? remainingGasTo : owner,
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
        @param notify Notify receiver on incoming transfer
        @param payload Notification payload
    */
    function internalTransfer(uint128 amount, address sender, address remainingGasTo, bool notify, TvmCell payload)
        override
        external
    {
        require(notify || !onlyNotifiableTransfers_ || callback_.value == 0,
                TokenErrors.RECIPIENT_ALLOWS_ONLY_NOTIFIABLE);
        address expectedSenderWallet = _getExpectedAddress(sender);
        require(msg.sender == expectedSenderWallet, TokenErrors.SENDER_IS_NOT_VALID_WALLET);
        require(sender != owner, TokenErrors.WRONG_RECIPIENT);
        uint128 reserve = math.max(TokenGas.TARGET_WALLET_BALANCE, address(this).balance - msg.value);
        require(address(this).balance > reserve, TokenErrors.LOW_GAS_VALUE);

        balance += amount;

        tvm.rawReserve(reserve, 0);

        if (notify && callback_.value != 0) {
            ITokenWalletCallback(callback_).onTokenTransferReceived{ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + 2, bounce: false }(
                address(this),
                root,
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
        require(amount <= balance, TokenErrors.NOT_ENOUGH_BALANCE);

        _reserve();

        balance -= amount;

        IBurnableTokenRoot(root).tokensBurned{ value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: true }(
            amount,
            owner,
            remainingGasTo.value != 0 ? remainingGasTo : owner,
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
        @param callback_payload Part of root callback data
    */
    function burnByRoot(uint128 amount, address remainingGasTo, address callbackTo, TvmCell payload)
        override
        external
        onlyRoot
    {
        require(amount > 0, TokenErrors.WRONG_AMOUNT);
        require(amount <= balance, TokenErrors.NOT_ENOUGH_BALANCE);

        balance -= amount;

        IBurnableTokenRoot(root).tokensBurned{ value: 0, flag: MsgFlag.REMAINING_GAS, bounce: true }(
            amount,
            owner,
            remainingGasTo,
            callbackTo,
            payload
        );
    }

    /*
        @notice Set new callbacks address
        @dev Set 0:0 in case you want to disable callbacks
        @param callback Receive callback receiver
        @param onlyNotifiableTransfers Wallet don't receive transfers without notify
    */
    function setCallback(address callback, bool onlyNotifiableTransfers) override external onlyOwner {
        callback_ = callback;
        onlyNotifiableTransfers_ = onlyNotifiableTransfers;

        if (callback.value != 0) {
            _reserve();
            ITokenWalletCallback(callback).callbackConfigured{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS,
bounce: false
            }(onlyNotifiableTransfers_);
        }
    }

    /*
        @notice Destroy token wallet and withdraw EVERs balance
        @dev Requires 0 token balance
        @param gas_dest EVERs receiver
    */
    function destroy(address remainingGasTo) override external onlyOwner {
        require(balance == 0, TokenErrors.NON_EMPTY_BALANCE);
        remainingGasTo.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.DESTROY_IF_ZERO, bounce: false });
    }

    // =============== Support functions ==================

    modifier onlyRoot() {
        require(root == msg.sender, TokenErrors.NOT_ROOT);
        _;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, TokenErrors.NOT_OWNER);
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
    function _getExpectedAddress(address owner_) private view returns (address) {
        TvmCell stateInit = tvm.buildStateInit({
            contr: TokenWallet,
            varInit: {
                root: root,
                owner: owner_
            },
            pubkey: 0,
            code: tvm.code()
        });

        return address(tvm.hash(stateInit));
    }

    /*
        @notice On-bounce handler
        @dev Catch bounce if internalTransfer or tokensBurned fails
        @dev If transfer fails - increase back tokens balance and notify callback_
        @dev If tokens burn root token callback fails - increase back tokens balance
        @dev Withdraws gas to owner by default if internal ownership is used
        @dev Or sends gas to bounce_callback if it's enabled
    */
    onBounce(TvmSlice body) external {
        uint32 functionId = body.decode(uint32);

        if (functionId == tvm.functionId(ITokenWallet.internalTransfer)) {
            uint128 amount = body.decode(uint128);
            balance += amount;
            _reserve();
            if (callback_.value != 0) {
                ITokenWalletCallback(callback_).onTokenTransferReverted{
                    value: 0,
                    flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS,
                    bounce: false
                }(
                    address(this),
                    root,
                    amount,
                    msg.sender
                );
            } else {
                owner.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS, bounce: false });
            }
        } else if (functionId == tvm.functionId(IBurnableTokenRoot.tokensBurned)) {
            uint128 amount = body.decode(uint128);
            balance += amount;
            if (callback_.value != 0) {
                _reserve();
                ITokenBurnRevertedCallback(callback_).onTokenBurnReverted{
                    value: 0,
                    flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS,
                    bounce: false
                }(
                    address(this),
                    root,
                    amount
                );
            } else {
                _reserve();
                owner.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS, bounce: false });
            }
        }
    }
}
