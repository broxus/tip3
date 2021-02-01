pragma solidity >= 0.6.0;
pragma AbiHeader expire;

import "./AllowanceInfoStructure.sol";

interface ITONTokenWallet is AllowanceInfoStructure {

    struct ITONTokenWalletDetails {
        bytes name;
        bytes symbol;
        uint8 decimals;
        address root_address;
        TvmCell code;
        uint256 wallet_public_key;
        address owner_address;
        uint128 balance;
    }

    function getDetails() external view returns (ITONTokenWalletDetails);

    function accept(uint128 tokens) external;

    function allowance() external view returns (AllowanceInfo);
    function approve(address spender, uint128 remaining_tokens, uint128 tokens) external;
    function disapprove() external;

    function transfer(address to, uint128 tokens, uint128 grams) external;
    function transferFrom(address from, address to, uint128 tokens, uint128 grams) external;

    function internalTransfer(uint128 tokens, uint256 sender_public_key, address sender_address, address send_gas_to) external;
    function internalTransferFrom(address to, uint128 tokens, address send_gas_to) external;

}
