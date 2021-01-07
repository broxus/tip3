pragma solidity >= 0.6.0;
pragma AbiHeader expire;

import "./AllowanceInfoStructure.sol";

interface ITONTokenWallet is AllowanceInfoStructure {

    function getName() external view returns (bytes);
    function getSymbol() external view returns (bytes);
    function getDecimals() external view returns (uint8);
    function getRootAddress() external view returns (address);
    function getOwnerAddress() external view returns (address);
    function getWalletPublicKey() external view returns (uint256);
    function getBalance() external view returns (uint128);
    function allowance() external view returns (AllowanceInfo);

    function accept(uint128 tokens) external;

    function approve(address spender, uint128 remaining_tokens, uint128 tokens) external;
    function disapprove() external;

    function transfer(address to, uint128 tokens, uint128 grams) external;
    function transferFrom(address from, address to, uint128 tokens, uint128 grams) external;

    function internalTransfer(uint128 tokens, uint256 sender_public_key, address sender_address, address send_gas_to) external;
    function internalTransferFrom(address to, uint128 tokens, address send_gas_to) external;

}
