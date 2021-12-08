# Tokens fungible smart contracts

Tokens fungible contracts implementation with burn support + tests.

## Configuration

Set up FreeTON configuration in `env/` directory. Use `template` files as a basic example and fill the empty fields. 

### Free TON

FreeTON env configuration will probably change, keep your eyes on.

- Use `NETWORK` http://ton_node in case you're using Docker compose
- Use `SEED` to generate keys. Seed can be generated with `tonos-cli genphrase`
- Leave `RANDOM_TRUFFLE_NONCE` blank if you need to determine contract address. Means, that test can be run only once. Set it `1` to deploy new addresses each time.

## Compiler & tvm_linker versions

 - [Compiler](https://github.com/tonlabs/TON-Solidity-Compiler/tree/064c5a4c6e021d294dcb465dad408a06d0b75168)
 - [Linker](https://github.com/tonlabs/TVM-linker/tree/cd1b33dd972d073a19a47054184ef76bfe408c2f)

## Local run

This section explains how to run and test contracts locally.

### Node version

Following versions were used for development

```
npm --version
6.14.8
node --version
v10.22.1
```

### Installation

Install all the dependencies for FreeTON.

```
npm install
```

### FreeTON

#### Run the local TON node

Use the [TON local-node](https://hub.docker.com/r/tonlabs/local-node) for local environment.

```
docker run --rm -d --name local-node -p80:80 tonlabs/local-node
```

#### Prepare the smart contracts

By default, there're all the necessary artifacts at the `free-ton/build/` directory. To rebuild the contracts, use the one liner:

```
npm run compile-ton
```

#### Run the migrations

```
npm run migrate-ton
```

#### Run the tests

```
npm run test-ton
```
