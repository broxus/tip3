pragma solidity >= 0.6.0;

pragma AbiHeader time;
pragma AbiHeader expire;

import "../interfaces/ITONTokenWallet.sol";

contract TONTokenWalletHack {
    bytes public static name;
    bytes public static symbol;
    uint8 public static decimals;
    address public static root_address;
    TvmCell public static code;
    //for external owner
    uint256 public static wallet_public_key;
    //for internal owner
    address public static owner_address;

    constructor() public {
        tvm.accept();
    }

    function mint(address to, uint128 tokens, uint128 grams) external view {
        tvm.accept();
        ITONTokenWallet(to).internalTransfer{value: grams, bounce: false}(tokens, wallet_public_key, owner_address, address(this));
    }
}
