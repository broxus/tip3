pragma ton-solidity >= 0.39.0;

pragma AbiHeader expire;

import "../interfaces/IRootTokenContract.sol";

contract DeployEmptyWalletFor {

    uint256 static _randomNonce;
    address static root;

    uint256 latest_pubkey;
    address latest_addr;

    constructor() public {
        tvm.accept();
    }

    //key or addr
    function deployEmptyWalletFor(uint256 pubkey, address addr) external {
        tvm.accept();
        latest_pubkey = pubkey;
        latest_addr = addr;
        IRootTokenContract(root).deployEmptyWallet{value: 0.5 ton}(
            0.1 ton,
            pubkey,
            addr,
            address.makeAddrStd(0, 0)
        );
    }

    function getLatestPublicKey() external view returns(uint256) {
        return latest_pubkey;
    }

    function getLatestAddr() external view returns(address) {
        return latest_addr;
    }

    function getRoot() external view returns(address) {
        return root;
    }

}
