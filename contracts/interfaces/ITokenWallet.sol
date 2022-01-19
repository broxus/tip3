pragma ton-solidity >= 0.39.0;


interface ITokenWallet {

    struct TokenWalletDetails {
        // TokenRoot address
        address root;
        // TokenWallet owner
        address owner;
        // Balance of TokenWallet in tokens
        uint128 balance;
    }

    /*
        @notice Get details about token wallet
        @returns root TokenRoot address
        @returns owner TokenWallet owner
        @returns balance Tokens balance of TokenWallet
        @returns callback Address for callbacks, specified by owner (see ITokenWalletCallback)
        @return onlyNotifiableTransfers Wallet don't receive transfers without notify
    */
    function getDetails() external view responsible returns (TokenWalletDetails);

    /*
        @notice Get TokenWallet code
        @returns code TokenWallet code
    */
    function walletCode() external view responsible returns (TvmCell);

    /*
        @notice Get TokenWallet balance in tokens
        @returns balance TokenWallet balance in tokens
    */
    function balance() external view responsible returns (uint128);

    /*
        @notice Get TokenRoot address
        @returns TokenRoot address
    */
    function root() external view responsible returns (address);

    /*
        @notice Get TokenWallet owner address
        @returns owner TokenWallet owner address
    */
    function owner() external view responsible returns (address);

    /*
        @notice Accept minted tokens from root
        @dev Can be called only by TokenRoot
        @param amount How much tokens to accept
        @param remainingGasTo Remaining gas receiver
        @param notify Notify receiver on incoming mint
        @param payload Notification payload
    */
    function acceptMinted(
        uint128 amount,
        address remainingGasTo,
        bool notify,
        TvmCell payload
    ) external;

    /*
        @notice Transfer tokens and optionally deploy TokenWallet for recipient
        @dev Can be called only by TokenWallet owner
        @dev If deployWalletValue !=0 deploy token wallet for recipient using that gas value
        @param amount How much tokens to transfer
        @param recipient Tokens recipient address
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
    ) external;

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
    ) external;

    /*
        @notice Callback for transfer operation
        @dev Can be called only by another valid TokenWallet contract with same root
        @param amount How much tokens to receive
        @param sender Sender TokenWallet owner address
        @param remainingGasTo Remaining gas receiver
        @param notify Notify receiver on incoming transfer
        @param payload Notification payload
    */
    function internalTransfer(
        uint128 amount,
        address sender,
        address remainingGasTo,
        bool notify,
        TvmCell payload
    ) external;

}
