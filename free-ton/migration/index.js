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

  async function deployWithAttempts(params, attempts = 10) {
    if (attempts > 0) {
      let error = false;
      await migration.deploy(params).catch(e => {
        console.log(e);
        error = true;
      });
      if (error) {
        await deployWithAttempts(params, attempts - 1);
      }
    }
  }

  const TONTokenWallet = await freeton.requireContract(tonWrapper, 'TONTokenWallet');
  const RootTokenContractExternalOwner = await freeton.requireContract(tonWrapper, 'RootTokenContract');
  await deployWithAttempts({
    contract: RootTokenContractExternalOwner,
    constructorParams: {},
    initParams: {
      name_: freeton.utils.stringToBytesArray('FooToken'),
      symbol_: freeton.utils.stringToBytesArray('FOO'),
      decimals_: 0,
      wallet_code_: TONTokenWallet.code,
      root_public_key_: `0x${tonWrapper.keys[0].public}`,
      root_owner_address_: ZERO_ADDRESS
    },
    initialBalance: freeton.utils.convertCrystal('7.654', 'nano'),
    _randomNonce: true,
    alias: 'RootTokenContractExternalOwner'
  });

  await deployWithAttempts({
    contract: TONTokenWallet,
    constructorParams: {},
    initParams: {
      name_: freeton.utils.stringToBytesArray('FooToken'),
      symbol_: freeton.utils.stringToBytesArray('FOO'),
      decimals_: 0,
      root_address_: RootTokenContractExternalOwner.address,
      code_: TONTokenWallet.code,
      wallet_public_key_: `0x${tonWrapper.keys[4].public}`,
      owner_address_: ZERO_ADDRESS
    },
    _randomNonce: false,
    initialBalance: freeton.utils.convertCrystal('1.001', 'nano'),
    keyPair: tonWrapper.keys[4]
  }).catch(e => console.log(e));

  const RootTokenContractInternalOwnerTest = await freeton.requireContract(tonWrapper, 'RootTokenContractInternalOwnerTest');
  await deployWithAttempts({
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
  await deployWithAttempts({
    contract: RootTokenContractInternalOwner,
    constructorParams: {},
    initParams: {
      name_: freeton.utils.stringToBytesArray('BarToken'),
      symbol_: freeton.utils.stringToBytesArray('BAR'),
      decimals_: 0,
      wallet_code_: TONTokenWallet.code,
      root_public_key_: `0x0`,
      root_owner_address_: RootTokenContractInternalOwnerTest.address
    },
    initialBalance: freeton.utils.convertCrystal('2.201', 'nano'),
    _randomNonce: true,
    alias: 'RootTokenContractInternalOwner'
  }).catch(e => console.log(e));

  await RootTokenContractInternalOwnerTest.run('setRootAddressOnce', {
    root_address: RootTokenContractInternalOwner.address
  }, tonWrapper.keys[0]);

  const TONTokenWalletInternalOwnerTest = await freeton.requireContract(tonWrapper, 'TONTokenWalletInternalOwnerTest');
  await deployWithAttempts({
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
  await deployWithAttempts({
    contract: DeployEmptyWalletFor,
    constructorParams: {},
    initParams: {
      root: RootTokenContractExternalOwner.address
    },
    _randomNonce: true,
    initialBalance: freeton.utils.convertCrystal('2.301', 'nano')
  }).catch(e => console.log(e));

  const TONTokenWalletHack = await freeton.requireContract(tonWrapper, 'TONTokenWalletHack');
  await deployWithAttempts({
    contract: TONTokenWalletHack,
    constructorParams: {},
    initParams: {
      name_: freeton.utils.stringToBytesArray('FooToken'),
      symbol_: freeton.utils.stringToBytesArray('FOO'),
      decimals_: 0,
      root_address_: RootTokenContractExternalOwner.address,
      code_: TONTokenWalletHack.code,
      wallet_public_key_: `0x${tonWrapper.keys[9].public}`,
      owner_address_: ZERO_ADDRESS
    },
    _randomNonce: false,
    initialBalance: freeton.utils.convertCrystal('0.501', 'nano'),
    keyPair: tonWrapper.keys[9]
  }).catch(e => console.log(e));

  migration.logHistory();
  
  process.exit(0);
})();
