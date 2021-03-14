pragma solidity >= 0.6.0;

interface IRootTokenContract {

    struct IRootTokenContractDetails {
        bytes name;
        bytes symbol;
        uint8 decimals;
        TvmCell wallet_code;
        uint256 root_public_key;
        address root_owner_address;
        uint128 total_supply;
    }

    function getDetails() external view returns (IRootTokenContractDetails);

    function getWalletAddress(uint256 wallet_public_key, address owner_address) external returns(address);

    function deployWallet(
        uint128 tokens,
        uint128 deploy_grams,
        uint256 wallet_public_key,
        address owner_address,
        address gas_back_address
    ) external returns(address);

    function deployEmptyWallet(
        uint128 deploy_grams,
        uint256 wallet_public_key,
        address owner_address,
        address gas_back_address
    ) external returns(address);

    function mint(uint128 tokens, address to, address gas_back_address) external;

    function sendExpectedWalletAddress(uint256 wallet_public_key_, address owner_address_, address to) external;
}
