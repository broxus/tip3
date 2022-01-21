pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/IBurnableByRootTokenWallet.sol";
import "./interfaces/IBurnableTokenRoot.sol";
import "./interfaces/IBurnableByRootTokenRoot.sol";
import "./interfaces/IDisableableMintTokenRoot.sol";
import "./interfaces/IAcceptTokensBurnCallback.sol";
import "./interfaces/TIP3TokenWallet.sol";
import "./interfaces/TIP3TokenRoot.sol";
import "./interfaces/ITokenRoot.sol";
import "./interfaces/ITokenWallet.sol";
import "./TokenWallet.sol";
import "./libraries/TokenErrors.sol";
import "./interfaces/IVersioned.sol";
import "../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";


/*
    @title Fungible token  root contract
*/
contract TokenRoot is ITokenRoot, IDisableableMintTokenRoot, IBurnableTokenRoot, IBurnableByRootTokenRoot {

    uint256 static randomNonce_;
    address static deployer_;

    string static name_;
    string static symbol_;
    uint8 static decimals_;
    TvmCell static walletCode_;
    address static rootOwner_;

    uint128 totalSupply_;
    bool mintDisabled_;
    bool burnByRootDisabled_;
    bool burnPaused_;

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
                flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS,
                bounce: false
            });
        }
    }

    fallback() external {
    }

    // TODO
    function supportsInterface(bytes4 interfaceID) override external view responsible returns (bool) {
        bytes4 tip3TokenRoot = bytes4(
            tvm.functionId(TIP3TokenRoot.name) ^
            tvm.functionId(TIP3TokenRoot.symbol) ^
            tvm.functionId(TIP3TokenRoot.decimals) ^
            tvm.functionId(TIP3TokenRoot.totalSupply) ^
            tvm.functionId(TIP3TokenRoot.walletCode) ^
            tvm.functionId(TIP3TokenRoot.acceptBurn)
        );

        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } (
            interfaceID == tip3TokenRoot
        );
    }

    function getDetails() override external view responsible returns (TokenRootDetails) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } TokenRootDetails(
            name_,
            symbol_,
            decimals_,
            rootOwner_,
            totalSupply_
        );
    }

    function name() override external view responsible returns (string) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } name_;
    }

    function symbol() override external view responsible returns (string) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } symbol_;
    }

    function decimals() override external view responsible returns (uint8) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } decimals_;
    }

    function totalSupply() override external view responsible returns (uint128) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } totalSupply_;
    }

    function walletCode() override external view responsible returns (TvmCell) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } walletCode_;
    }

    function rootOwner() override external view responsible returns (address) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } rootOwner_;
    }

    function mintDisabled() override external view responsible returns(bool) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } mintDisabled_;
    }

    /*
        @notice Derive token wallet address from the public key or address
        @param walletOwner Token wallet owner address
        @returns walletOwner Token wallet address
    */
    function walletOf(address walletOwner)
        override
        public
        view
        responsible
        returns (address)
    {
        require(walletOwner.value != 0, TokenErrors.WRONG_WALLET_OWNER);
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } _getExpectedWalletAddress(walletOwner);
    }

    /*
        @notice Deploy new token wallet with empty tokens balance
        @dev Can be called by anyone to deploy new token wallet
        @param walletOwner Token wallet owner address
        @param deployWalletValue
    */
    function deployWallet(address walletOwner, uint128 deployWalletValue)
        public
        override
        responsible
        returns(address tokenWallet)
    {
        require(walletOwner.value != 0, TokenErrors.WRONG_WALLET_OWNER);
        tvm.rawReserve(_reserve(), 0);

        tokenWallet = new TokenWallet {
            value: deployWalletValue,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false,
            code: walletCode_,
            pubkey: 0,
            varInit: {
                root_: address(this),
                owner_: walletOwner
            }
        }();

        return { value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false } tokenWallet;
    }

    /*
        @notice Mint tokens to recipient with deploy wallet optional
        @dev Can be called only by owner
        @param amount How much tokens to mint
        @param recipient Minted tokens owner address
        @param deployWalletValue How much EVERs send to wallet on deployment, when == 0 then not deploy wallet before mint
        @param remainingGasTo Receiver the remaining balance after deployment. root owner by default
        @param notify - when TRUE and recipient specified 'callback' on his own TokenWallet,
                        then send IAcceptTokensTransferCallback.onAcceptTokensMint to specified callback address,
                        else this param will be ignored
        @param payload - custom payload for IAcceptTokensTransferCallback.onAcceptTokensMint
    */
    function mint(
        uint128 amount,
        address recipient,
        uint128 deployWalletValue,
        address remainingGasTo,
        bool notify,
        TvmCell payload
    )
        override
        external
        onlyRootOwner
    {
        require(!mintDisabled_, TokenErrors.MINT_DISABLED);
        require(amount > 0, TokenErrors.WRONG_AMOUNT);
        require(recipient.value != 0, TokenErrors.WRONG_RECIPIENT);

        tvm.rawReserve(_reserve(), 0);
        _mint(amount, recipient, deployWalletValue, remainingGasTo, notify, payload);
    }

    /*
    @notice Disable 'mint' forever
        @dev Can be called only by rootOwner_
        @dev This is an irreversible action
        @returns true
    */
    function disableMint() override external responsible onlyRootOwner returns(bool) {
        mintDisabled_ = true;
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } mintDisabled_;
    }

    /*
        @notice Burn tokens at specific token wallet
        @dev Can be called only by owner address
        @dev Don't support token wallet owner public key
        @param amount How much tokens to burn
        @param owner Token wallet owner address
        @param send_gas_to Receiver of the remaining balance after burn. sender_address by default
        @param callback_address Burn callback address
        @param callback_payload Burn callback payload
    */
    function burnTokens(
        uint128 amount,
        address walletOwner,
        address remainingGasTo,
        address callbackTo,
        TvmCell payload
    )
        override
        external
        onlyRootOwner
    {
        require(!burnPaused_, TokenErrors.BURN_PAUSED);
        require(!burnByRootDisabled_, TokenErrors.BURN_BY_ROOT_DISABLED);
        require(amount > 0, TokenErrors.WRONG_AMOUNT);
        require(walletOwner.value != 0, TokenErrors.WRONG_WALLET_OWNER);

        IBurnableByRootTokenWallet(_getExpectedWalletAddress(walletOwner)).burnByRoot{
            value: 0,
            bounce: true,
            flag: MsgFlag.REMAINING_GAS
        }(
            amount,
            remainingGasTo,
            callbackTo,
            payload
        );
    }

    function disableBurnByRoot() override external responsible onlyRootOwner returns(bool) {
        burnByRootDisabled_ = true;
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } burnByRootDisabled_;
    }

    function burnByRootDisabled() override external view responsible returns(bool) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } burnByRootDisabled_;
    }

    /*
        @notice Get burn paused status
        @returns paused
    */
    function burnPaused() override external view responsible returns(bool) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } burnPaused_;
    }

    /*
        @notice Pause/Unpause token burns
        @dev Can be called only by rootOwner_
        @dev if paused, then all burned tokens will be bounced to TokenWallet
        @param paused
        @returns paused
    */
    function setBurnPaused(bool paused) override external responsible onlyRootOwner returns(bool) {
        burnPaused_ = paused;
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } burnPaused_;
    }

    /*
        @notice Callback for token wallet tokens burn operation
        @dev Decrease total supply
        @dev Can be called only by correct token wallet contract
        @dev Fails if root token is paused
        @param tokens How much tokens was burned
        @param sender_public_key Token wallet owner public key
        @param sender_address Token wallet owner address
        @param send_gas_to Remaining balance receiver
        @param callback_address Callback receiver address
        @param callback_payload Callback payload
    */
    function acceptBurn(
        uint128 amount,
        TvmCell meta
    )
        override
        external
    {
        require(!burnPaused_, TokenErrors.BURN_PAUSED);
        TvmSlice metaSlice = meta.toSlice();
        address walletOwner = metaSlice.decode(address);
        require(msg.sender == _getExpectedWalletAddress(walletOwner), TokenErrors.SENDER_IS_NOT_VALID_WALLET);

        tvm.rawReserve(address(this).balance - msg.value, 2);

        address remainingGasTo = metaSlice.decode(address);
        address callbackTo = metaSlice.decode(address);
        TvmCell payload = metaSlice.loadRef();

        totalSupply_ -= amount;

        if (callbackTo.value == 0) {
            remainingGasTo.transfer({
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS,
                bounce: false
            });
        } else {
            IAcceptTokensBurnCallback(callbackTo).onAcceptTokensBurn{ value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false }(
                amount,
                walletOwner,
                msg.sender,
                remainingGasTo,
                payload
            );
        }

    }

    /*
        @notice Withdraw all surplus balance in EVERs
        @dev Can by called only by owner address
        @param to Withdraw receiver
    */
    function sendSurplusGas(address to) external view onlyRootOwner {
        tvm.rawReserve(TokenGas.TARGET_ROOT_BALANCE, 0);
        to.transfer({
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS,
            bounce: false
        });
    }


    /*
        @notice Transfer root token ownership
        @param new_owner Root token new owner address
    */
    function transferOwnership(address newRootOwner) external onlyRootOwner {
        rootOwner_ = newRootOwner;
    }

    // =============== Support functions ==================

    modifier onlyRootOwner() {
        require(rootOwner_.value != 0 && rootOwner_ == msg.sender, TokenErrors.NOT_OWNER);
        _;
    }

    function _reserve() internal pure returns (uint128) {
        return math.max(address(this).balance - msg.value, TokenGas.TARGET_WALLET_BALANCE);
    }

    function _mint(
        uint128 amount,
        address recipient,
        uint128 deployWalletValue,
        address remainingGasTo,
        bool notify,
        TvmCell payload
    )
        internal
    {
        TvmCell stateInit = _buildWalletInitData(recipient);

        address recipientWallet;

        if(deployWalletValue > 0) {
            recipientWallet = new TokenWallet {
                stateInit: stateInit,
                wid: address(this).wid,
                value: deployWalletValue,
                flag: MsgFlag.SENDER_PAYS_FEES,
                bounce: false
            }();
        } else {
            recipientWallet = address(tvm.hash(stateInit));
        }

        totalSupply_ += amount;

        TvmBuilder metaBuilder;
        metaBuilder.store(remainingGasTo);
        metaBuilder.store(notify);
        metaBuilder.store(payload);

        TIP3TokenWallet(recipientWallet).acceptMint{ value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: true }(
            amount,
            metaBuilder.toCell()
        );
    }

    /*
        @notice Derive wallet address from owner
        @param wallet_public_key_ Token wallet owner public key
        @param owner_address_ Token wallet owner address
    */
    function _buildWalletInitData(address walletOwner) private view returns (TvmCell) {
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

    /*
        @notice Derive wallet address from owner
        @param wallet_public_key_ Token wallet owner public key
        @param owner_address_ Token wallet owner address
    */
    function _getExpectedWalletAddress(address walletOwner) private view returns (address) {
        return address(tvm.hash(_buildWalletInitData(walletOwner)));
    }

    /*
        @notice On-bounce handler
        @dev Used in case token wallet .accept fails so the totalSupply_ can be decreased back
    */
    onBounce(TvmSlice slice) external {
        if (slice.decode(uint32) == tvm.functionId(TIP3TokenWallet.acceptMint)) {
            totalSupply_ -= slice.decode(uint128);
        }
    }

}
