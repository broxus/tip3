pragma ton-solidity >= 0.39.0;

import "./TIP3TokenWallet.sol";
import "./TIP4.sol";

interface ITokenWallet is TIP3TokenWallet, TIP4 {

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
    */
    function getDetails() external view responsible returns (TokenWalletDetails);

    /*
        @notice Get TokenWallet owner address
        @returns owner TokenWallet owner address
    */
    function owner() external view responsible returns (address);

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
        uint128 _amount,
        address _recipient,
        uint128 _deployWalletValue,
        address _remainingGasTo,
        bool _notify,
        TvmCell _payload
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
        uint128 _amount,
        address _recipientTokenWallet,
        address _remainingGasTo,
        bool _notify,
        TvmCell _payload
    ) external;

}
