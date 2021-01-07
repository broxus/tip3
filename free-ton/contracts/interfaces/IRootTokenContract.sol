pragma solidity >= 0.6.0;
pragma AbiHeader expire;

interface IRootTokenContract {
    function getName() external view returns (bytes);
    function getSymbol() external view returns (bytes);
    function getDecimals() external view returns (uint8);
    function getRootPublicKey() external view returns (uint256);
    function getRootOwnerAddress() external view returns (address);
    function getWalletCode() external view returns (TvmCell);

    function getTotalSupply() external view returns (uint128);

    function getWalletAddress(uint256 wallet_public_key, address owner_address) external returns (address);

    function deployWallet(
        uint128 tokens,
        uint128 grams,
        uint256 wallet_public_key,
        address owner_address,
        address gas_back_address
    ) external returns (address);

    function deployEmptyWallet(
        uint128 grams,
        uint256 wallet_public_key,
        address owner_address,
        address gas_back_address
    ) external returns (address);

    function mint(uint128 tokens, address to) external;
}
