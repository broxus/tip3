pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;

import "../interfaces/IExpectedWalletAddressCallback.sol";
import "../interfaces/IRootTokenContract.sol";

contract ExpectedWalletAddressTest is IExpectedWalletAddressCallback {

    address static root_address;
    address public wallet;

    constructor() public {
        tvm.accept();
        IRootTokenContract(root_address).deployEmptyWallet{value: 0.5 ton}(0.1 ton, 0, address(this), address(this));
        IRootTokenContract(root_address).sendExpectedWalletAddress{value: 0.1 ton}(0, address(this), address(this));
    }

    function expectedWalletAddressCallback(
        address wallet_,
        uint256 wallet_public_key,
        address owner_address
    ) override external {
        require(msg.sender == root_address);
        require(wallet_public_key == 0);
        require(owner_address == address(this));

        wallet = wallet_;
    }
}
