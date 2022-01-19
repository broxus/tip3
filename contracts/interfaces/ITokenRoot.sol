pragma ton-solidity >= 0.39.0;


interface ITokenRoot {

    struct TokenRootDetails {
        // Basic info about token
        string name;
        string symbol;
        uint8 decimals;

        // TokenRoot owner
        address rootOwner;

        // Token total supply
        uint128 totalSupply;
    }

    /*
        @notice Get root token details
        @returns name Token name
        @returns symbol Token symbol
        @returns decimals Token decimals
        @returns rootOwner Owner address
        @returns totalSupply Token total supply
    */
    function getDetails() external view responsible returns (TokenRootDetails);

    /*
        @notice Get total supply
        @returns totalSupply Token total supply
    */
    function totalSupply() external view responsible returns (uint128);

    /*
        @notice Get root owner
        @returns rootOwner
    */
    function rootOwner() external view responsible returns (address);

    /*
        @notice Get TokenWallet code
        @returns code TokenWallet code
    */
    function walletCode() external view responsible returns (TvmCell);

    /*
        @notice Derive TokenWallet address from owner address
        @param walletOwner TokenWallet owner address
        @returns tokenWallet Token wallet address
    */
    function walletOf(address _owner) external view responsible returns(address tokenWallet);

    /*
        @notice Mint tokens to recipient with deploy wallet optional
        @dev Can be called only by rootOwner
        @param amount How much tokens to mint
        @param recipient Minted tokens owner address
        @param deployWalletValue How much EVERs send to wallet on deployment, when == 0 then not deploy wallet before mint
        @param remainingGasTo Receiver the remaining balance after deployment. root owner by default
        @param notify - when TRUE and recipient specified 'callback' on his own TokenWallet,
                        then send ITokenWalletCallback.onAcceptMintedTokens to specified callback address,
                        else this param will be ignored
        @param payload - custom payload for ITokenWalletCallback.onAcceptMintedTokens
    */
    function mint(
        uint128 amount,
        address recipient,
        uint128 deployWalletValue,
        address remainingGasTo,
        bool notify,
        TvmCell payload
    ) external;

    /*
        @notice Deploy new TokenWallet
        @dev Can be called by anyone
        @param walletOwner Token wallet owner address
        @param callbackTo When != 0:0 then will lead to send ITokenWalletDeployedCallback(callbackTo).onTokenWalletDeployed from root
    */
    function deployWallet(
        address walletOwner,
        uint128 deployWalletValue
    ) external responsible returns(address tokenWallet);
}
