pragma ton-solidity ^0.38.2;
pragma AbiHeader expire;

interface ITransferOwner {
    function transferOwner(uint256 external_owner_pubkey_, address internal_owner_address_) external;
}
