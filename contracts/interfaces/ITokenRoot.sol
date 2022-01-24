pragma ton-solidity >= 0.39.0;

import "./TIP3TokenRoot.sol";
import "./TIP5.sol";

interface ITokenRoot is TIP3TokenRoot, TIP5 {

    /*
        @notice Get root owner
        @returns rootOwner
    */
    function rootOwner() external view responsible returns(address);

    /*
        @notice Derive TokenWallet address from owner address
        @param _owner TokenWallet owner address
        @returns Token wallet address
    */
    function walletOf(address _owner) external view responsible returns(address);

    /*
        @notice Called by TokenWallet, when
        @dev Decrease total supply
        @dev Can be called only by correct token wallet contract
        @dev Fails if root token burn paused
        @param amount How much tokens was burned
        @param walletOwner Burner TokenWallet owner address
        @param remainingGasTo Receiver of the remaining EVERs
        @param callbackTo address of contract, which implement IBurnTokensCallback.burnCallback
               if it equals to 0:0 then no callbacks
        @param payload Custom data will be delivered into IBurnTokensCallback.burnCallback
    */
    function acceptBurn(
        uint128 amount,
        address walletOwner,
        address remainingGasTo,
        address callbackTo,
        TvmCell payload
    ) external functionID(0x192B51B1);

    /*
        @notice Mint tokens to recipient with deploy wallet optional
        @dev Can be called only by rootOwner
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
        uint128 _amount,
        address _recipient,
        uint128 _deployWalletValue,
        address _remainingGasTo,
        bool _notify,
        TvmCell _payload
    ) external;

    /*
        @notice Deploy new TokenWallet
        @dev Can be called by anyone
        @param walletOwner Token wallet owner address
        @param callbackTo When != 0:0 then will lead to send ITokenWalletDeployedCallback(callbackTo).onTokenWalletDeployed from root
    */
    function deployWallet(
        address _owner,
        uint128 _deployWalletValue
    ) external responsible returns(address);
}
