require('dotenv').config({ path: './../env/freeton.env' });

const freeton = require('ton-testing-suite');

const LOG_KEY_PAIRS_N = 11;

const giverConfig = {
  address: process.env.GIVER_CONTRACT,
  abi: JSON.parse(process.env.GIVER_ABI),
};
const config = {
  messageExpirationTimeout: 60000
};

const tonWrapper = new freeton.TonWrapper({
  network: process.env.NETWORK,
  seed: process.env.SEED,
  giverConfig,
  config
});

// Deploy contracts
(async () => {
  await tonWrapper.setup();

  tonWrapper.keys.map((key, i) => {
    if(i <= LOG_KEY_PAIRS_N) {
      console.log(`Key #${i} - ${JSON.stringify(key)}`);
    }
  });

  const migration = new freeton.Migration(tonWrapper);
  const ZERO_ADDRESS = '0:0000000000000000000000000000000000000000000000000000000000000000';

  const TONTokenWallet = await freeton.requireContract(tonWrapper, 'TONTokenWallet');
  const RootTokenContractExternalOwner = await freeton.requireContract(tonWrapper, 'RootTokenContract');
  await migration.deploy({
    contract: RootTokenContractExternalOwner,
    constructorParams: {},
    initParams: {
      name: freeton.utils.stringToBytesArray('FooToken'),
      symbol: freeton.utils.stringToBytesArray('FOO'),
      decimals: 0,
      wallet_code: TONTokenWallet.code,
      root_public_key: `0x${tonWrapper.keys[0].public}`,
      root_owner_address: ZERO_ADDRESS
    },
    initialBalance: freeton.utils.convertCrystal('7.654', 'nano'),
    _randomNonce: true,
    alias: 'RootTokenContractExternalOwner'
  });

  await migration.deploy({
    contract: TONTokenWallet,
    constructorParams: {},
    initParams: {
      name: freeton.utils.stringToBytesArray('FooToken'),
      symbol: freeton.utils.stringToBytesArray('FOO'),
      decimals: 0,
      root_address: RootTokenContractExternalOwner.address,
      code: TONTokenWallet.code,
      wallet_public_key: `0x${tonWrapper.keys[4].public}`,
      owner_address: ZERO_ADDRESS
    },
    _randomNonce: false,
    initialBalance: freeton.utils.convertCrystal('2.001', 'nano'),
    keyPair: tonWrapper.keys[4]
  }).catch(e => console.log(e));

  const RootTokenContractInternalOwnerTest = await freeton.requireContract(tonWrapper, 'RootTokenContractInternalOwnerTest');
  await migration.deploy({
    contract: RootTokenContractInternalOwnerTest,
    constructorParams: {},
    initParams:{
        external_owner_pubkey_: `0x${tonWrapper.keys[0].public}`,
        internal_owner_address_: ZERO_ADDRESS
      },
    initialBalance: freeton.utils.convertCrystal('9.101', 'nano'),
    _randomNonce: true,
    keyPair: tonWrapper.keys[0]
  }).catch(e => console.log(e));

  const RootTokenContractInternalOwner = await freeton.requireContract(tonWrapper, 'RootTokenContract');
  await migration.deploy({
    contract: RootTokenContractInternalOwner,
    constructorParams: {},
    initParams: {
      name: freeton.utils.stringToBytesArray('BarToken'),
      symbol: freeton.utils.stringToBytesArray('BAR'),
      decimals: 0,
      wallet_code: TONTokenWallet.code,
      root_public_key: `0x0`,
      root_owner_address: RootTokenContractInternalOwnerTest.address
    },
    initialBalance: freeton.utils.convertCrystal('2.201', 'nano'),
    _randomNonce: true,
    alias: 'RootTokenContractInternalOwner'
  }).catch(e => console.log(e));

  await RootTokenContractInternalOwnerTest.run('setRootAddressOnce', {
    root_address: RootTokenContractInternalOwner.address
  }, tonWrapper.keys[0]);

  const TONTokenWalletInternalOwnerTest = await freeton.requireContract(tonWrapper, 'TONTokenWalletInternalOwnerTest');
  await migration.deploy({
    contract: TONTokenWalletInternalOwnerTest,
    constructorParams: {},
    initParams: {
      external_owner_pubkey_: `0x${tonWrapper.keys[5].public}`
    },
    initialBalance: freeton.utils.convertCrystal('10.001', 'nano'),
    _randomNonce: true,
    keyPair: tonWrapper.keys[5]
  }).catch(e => console.log(e));

  const DeployEmptyWalletFor = await freeton.requireContract(tonWrapper, 'DeployEmptyWalletFor');
  await migration.deploy({
    contract: DeployEmptyWalletFor,
    constructorParams: {},
    initParams: {
      root: RootTokenContractExternalOwner.address
    },
    _randomNonce: true,
    initialBalance: freeton.utils.convertCrystal('4.301', 'nano')
  }).catch(e => console.log(e));

  const TONTokenWalletHack = await freeton.requireContract(tonWrapper, 'TONTokenWalletHack');
  await migration.deploy({
    contract: TONTokenWalletHack,
    constructorParams: {},
    initParams: {
      name: freeton.utils.stringToBytesArray('FooToken'),
      symbol: freeton.utils.stringToBytesArray('FOO'),
      decimals: 0,
      root_address: RootTokenContractExternalOwner.address,
      code: TONTokenWalletHack.code,
      wallet_public_key: `0x${tonWrapper.keys[9].public}`,
      owner_address: ZERO_ADDRESS
    },
    _randomNonce: false,
    initialBalance: freeton.utils.convertCrystal('0.501', 'nano'),
    keyPair: tonWrapper.keys[9]
  }).catch(e => console.log(e));

  migration.logHistory();
  
  process.exit(0);
})();
