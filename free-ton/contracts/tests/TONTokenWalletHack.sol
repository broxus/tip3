pragma solidity >= 0.6.0;

pragma AbiHeader time;
pragma AbiHeader expire;

import "../interfaces/ITONTokenWallet.sol";

contract TONTokenWalletHack {
    bytes static name_;
    bytes static symbol_;
    uint8 static decimals_;
    address static root_address_;
    TvmCell static code_;
    //for external owner
    uint256 static wallet_public_key_;
    //for internal owner
    address static owner_address_;

    constructor() public {
        tvm.accept();
    }

    function mint(address to, uint128 tokens, uint128 grams) external view {
        tvm.accept();
        ITONTokenWallet(to).internalTransfer{value: grams, bounce: false}(tokens, wallet_public_key_, owner_address_, address(this));
    }
}
