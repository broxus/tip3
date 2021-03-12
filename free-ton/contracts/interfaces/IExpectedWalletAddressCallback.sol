pragma solidity >= 0.6.0;
pragma AbiHeader expire;

interface IExpectedWalletAddressCallback {
    function expectedWalletAddressCallback(
        address wallet,
        uint256 wallet_public_key,
        address owner_address
    ) external;
}
