# Fungible token standard

## Simple summary

A standard interface for tokens.

## Abstract
The following standard allows for the implementation of a standard API for tokens within smart contracts. This standard provides basic functionality to transfer tokens.

General information about token is stored in the [Root](#root) contract. Each token holder has its own instance of [Token wallet](#token-wallet) contract. Token transfers SHOULD be implemented
in P2P fashion, between sender and receiver token wallets. Third party contracts MAY implement some or all [hooks](#hooks) to
receive callbacks on token actions.

## Motivation
A standard interface allows any tokens on Everscale to be re-used by other applications: from wallets to decentralized exchanges.

## Specification

### Root

#### Name

Returns the name of the token - e.g. "MyToken".

```solidity
function name() public view responsible returns(string);
```

#### Symbol

Returns the symbol of the token. E.g. “HIX”.

```solidity
function symbol() public view responsible returns (string);
```

#### Decimals

Returns the number of decimals the token uses - e.g. 8, means to divide the token amount by 100000000 to get its user representation.

```solidity
function decimals() public view responsible returns (uint8);
```

#### Total supply

Returns the total token supply.

```solidity
function totalSupply() public view responsible returns (uint128);
```

#### Token wallet code

Returns the token wallet code.

```solidity
function walletCode() public view responsible returns (TvmCell);
```

#### Derive token wallet address

Returns the expected token wallet address with owner `_owner`.

```solidity
function walletOf(address _owner) public view responsible returns (address);
```

#### Deploy token wallet

Deploys instance of token wallet contract owned by `_owner`, `deployWalletValue` SHOULD be attached
to the deployment message. Returns token wallet address.

```solidity
function deployWallet(address _owner, uint128 deployWalletValue) public responsible(address);
```

### Token wallet

#### Owner

Returns the token wallet owner.

```solidity
function owner() public view responsible returns(address);
```

#### Balance

Returns the token wallet balance.

```solidity
function balance() public view responsible returns(uint128);
```

#### Transfer

Transfers `amount` of tokens to a token wallet, owned by `recipient`. The function MUST `revert` if the token wallet balance
does not have enough tokens to spend.

If `deployWalletValue` is greater than `0`, token wallet MUST send a deployment message for recipient token wallet.

If `notify` is `true` and transfer callback recipient 

The rest of the attached value MUST be transferred to the `remainingGasTo`.

```solidity
function transfer(
    uint128 amount,
    address recipient,
    uint128 deployWalletValue,
    bool notify,
    TvmCell payload,
    address remainingGasTo
) public;
```

#### Wallet code

Returns the token wallet code.

```solidity
function walletCode() public view responsible returns (TvmCell);
```

#### Set callback

Sets callback recipient to `recipient`. If `recipient` is `0:0000000000000000000000000000000000000000000000000000000000000000`, than
token wallet SHOULD NOT send a `onTokenTransferReceived` callback when receiving tokens.

```solidity
function setCallback(address recipient) public;
```

### Hooks

These hooks MAY be implemented in a contract (hereafter referred to as the "Dapp") in order to receive callbacks from token wallet.

#### On callback configured

Called by token wallet when Dapp is set as callback recipient in token wallet.

```solidity
function onCallbackConfigured() public;
```

#### On tokens transfer received

MUST be called by token wallet when tokens transfer received, when Dapp is set as callback recipient.

```solidity
function onTokenTransferReceived(
    address tokenRoot,
    uint128 amount,
    address sender,
    address senderWallet,
    address remainingGasTo,
    TvmCell payload
) public;
```

#### On tokens transfer reverted

MUST be called by token wallet when tokens transfer, initiated by Dapp, is reverted.

```solidity
function onTokenTransferReverted(
    address tokenRoot,
    uint128 amount,
    address revertedFrom
) public;
```