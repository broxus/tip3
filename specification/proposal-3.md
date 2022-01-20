# Fungible token standard

## Simple summary

A standard interface for fungible tokens.

Requires: [TIP2](./proposal-4.md)

## Abstract

The following standard allows for the implementation of a standard API for tokens within smart contracts. General information about token is stored in the [token root](#token-root) contract.
Each token holder has its own instance of [token wallet](#token-wallet) contract. Token transfers SHOULD be implemented in P2P fashion, between sender and receiver token wallets.

## Motivation

A standard interface allows any tokens on Everscale to be re-used by other applications: from wallets to decentralized exchanges.

## Specification

The keywords “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”, “SHOULD NOT”, “RECOMMENDED”, “MAY”, and “OPTIONAL” in this document are to be interpreted as described in RFC 2119.

### Notes

- We choose Standard Interface Detection to expose the interfaces that a TIP3 smart contract supports.
- This standard does not define the external methods to initiate transfer, mint or burn tokens. Though it defines the methods, which MUST be called on a recipient token wallet or token root during these operations. Any additional data MUST be encoded in the `_meta` parameter. This allows to detect these operations, without knowing the details of a specific implementation.
- The rules for decoding `_meta` parameters MUST be defined in a child standards.
- The rules for a token wallet ownership MUST be defined in a child standards.

### Token root

#### Name

Returns the name of the token - e.g. "MyToken".

```solidity
function name() public view responsible returns (string);
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

#### Accept tokens burn

MUST be called by the token wallet. Before sending this message, caller token wallet MUST decrease its own balance by `_value`. Decreases total supply by `_value` amount of tokens. Any additional data MUST be encoded in the `_meta` parameter. If the mint can't be accepted (e.g. invalid sender), this message MUST be reverted.

```solidity
function acceptBurn(
    uint128 _value,
    TvmCell _meta
) external;
```

#### Detect interface

The TIP4 interface ID for the TIP3 token root is **TO BE DEFINED**.

### Token wallet

#### Root

Returns the token root address.

```solidity
function root() public view responsible returns (address);
```

#### Balance

Returns the token wallet balance.

```solidity
function balance() public view responsible returns (uint128);
```

#### Wallet code

Returns the token wallet code.

```solidity
function walletCode() public view responsible returns (TvmCell);
```

#### Accept tokens transfer

MUST be called by another token wallet. Before sending this message, caller token wallet MUST decrease its own balance by `_value`. Adds `_value` amount of tokens to the balance of the called token wallet. Any additional data MUST be encoded in the `_meta` parameter. If the transfer can't be accepted (e.g. invalid sender), this message MUST be reverted.

```solidity
function acceptTransfer(
    uint128 _value,
    TvmCell _meta
) external;
```

#### Accept tokens mint

MUST be called by the token root. Before sending this message, token root MUST increase the total supply by `_value`. Adds `_value` amount of tokens to the balance of the called token wallet. Any additional data MUST be encoded in the `_meta` parameter. If the mint can't be accepted (e.g. invalid sender), this message MUST be reverted.

```solidity
function acceptMint(
    uint128 _value,
    TvmCell _meta
) external;
```

#### Standard interface detection

The token wallet The TIP4 interface ID for the TIP3 token wallet is **TO BE DEFINED**.`