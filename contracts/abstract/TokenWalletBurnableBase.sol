pragma ton-solidity >= 0.57.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./TokenWalletBase.sol";
import "../interfaces/ITokenRoot.sol";
import "../interfaces/IBurnableTokenWallet.sol";
import "../libraries/TokenErrors.sol";
import "../libraries/TokenMsgFlag.sol";

/**
 * @dev Implementation of the {IBurnableTokenWallet} interface.
 *
 * This abstraction extends the functionality of {TokenWalletBase} and adding
 * burning self-tokens functional.
 */
abstract contract TokenWalletBurnableBase is TokenWalletBase, IBurnableTokenWallet {

    /**
     * @dev See {IBurnableTokenWallet-burn}.
     *
     * Burn tokens from the wallet.
     *
     * Precondition:
     *
     *  - `sender` must be the wallet owner.
     *
     * For implementation details, see {TokenWalletBase-_burn}.
     */
    function burn(uint128 amount, address remainingGasTo, address callbackTo, TvmCell payload)
        override
        external
        onlyOwner
    {
        _burn(amount, remainingGasTo, callbackTo, payload);
    }
}
