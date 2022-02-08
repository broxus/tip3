pragma ton-solidity >= 0.57.0;

import "../libraries/TokenErrors.sol";
import "../libraries/TokenMsgFlag.sol";


abstract contract TokenFactoryBase {

    uint256 static _nonce;

    address public _owner;
    address public _pendingOwner;
    uint256 public _tokenNonce;
    uint128 public _deployValue;

    TvmCell public _rootCode;
    TvmCell public _walletCode;


    modifier onlyOwner {
        require(msg.sender == _owner && _owner.value != 0, TokenErrors.NOT_OWNER);
        _;
    }

    modifier cashBack {
        _;
        msg.sender.transfer({value: 0, flag: TokenMsgFlag.REMAINING_GAS, bounce: false});
    }


    constructor(address owner, uint128 deployValue, TvmCell rootCode, TvmCell walletCode) public {
        tvm.accept();
        _owner = owner;
        _deployValue = deployValue;
        _rootCode = rootCode;
        _walletCode = walletCode;
    }


    function deployRoot(
        string name,        // static
        string symbol,      // static
        uint8 decimals,     // static
        address owner,      // static
        address initialSupplyTo,
        uint128 initialSupply,
        uint128 deployWalletValue,
        bool mintDisabled,
        bool burnByRootDisabled,
        bool burnPaused,
        address remainingGasTo
    ) external responsible virtual returns (address);

    function _buildStateInit(
        uint256 nonce,
        string name,
        string symbol,
        uint8 decimals,
        address owner
    ) internal view virtual returns (TvmCell);

    function changeDeployValue(uint128 deployValue) public onlyOwner cashBack {
        _deployValue = deployValue;
    }

    function changeRootCode(TvmCell rootCode) public onlyOwner cashBack {
        _rootCode = rootCode;
    }

    function changeWalletCode(TvmCell walletCode) public onlyOwner cashBack {
        _walletCode = walletCode;
    }

    function transferOwner(address owner) public onlyOwner cashBack {
        _pendingOwner = owner;
    }

    function acceptOwner() public cashBack {
        require(msg.sender == _pendingOwner && _pendingOwner.value != 0, TokenErrors.NOT_OWNER);
        _owner = _pendingOwner;
        _pendingOwner = address(0);
    }

    function upgrade(TvmCell code) public virtual;

}
