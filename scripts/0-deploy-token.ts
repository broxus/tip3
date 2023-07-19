import { Address, toNano, zeroAddress } from 'locklift';
import BigNumber from 'bignumber.js';
import { Command } from 'commander';
import prompts, { PromptObject } from 'prompts';
import { isNumeric, isValidEverAddress } from './helpers/utils';

const program = new Command();

async function main() {
  console.log('0-DEPLOY-TOKEN');
  await locklift.deployments.load();

  const promptsData: PromptObject[] = [];

  program
    .allowUnknownOption()
    .option('-ro, --root_owner <root_owner>', 'Root owner')
    .option('-upgradeable, --upgradeable <boolean>', 'Deploy upgradeable token')
    .option('-name, --name <name>', 'Name')
    .option('-symb, --symbol <symbol>', 'Symbol')
    .option('-dec, --decimals <decimals>', 'Decimals')
    .option(
      '-ist, --initial_supply_to <initial_supply_to>',
      'Initial supply to (address)',
    )
    .option('-is, --initial_supply <initial_supply>', 'Initial supply (amount)')
    .option('-dsbm, --disable_mint <disable_mint>', 'Disable mint')
    .option(
      '-dsbrb, --disable_burn_by_root <disable_burn_by_root>',
      'Disable burn by root owner',
    )
    .option('-pb, --pause_burn <pause_burn>', 'Pause burn');

  program.parse(process.argv);

  const options = program.opts();

  let disableMint;
  let disableBurnByRoot;
  let pauseBurn;
  let upgradeable;
  let initialSupply = 0;

  if (!isValidEverAddress(options.root_owner)) {
    promptsData.push({
      type: 'text',
      name: 'rootOwner',
      message: 'Root owner',
      validate: (value) =>
        isValidEverAddress(value) ? true : 'Invalid Ever address',
    });
  }

  if (!options.upgradeable) {
    promptsData.push({
      type: 'select',
      name: 'upgradeable',
      message: 'Deploy upgradeable token',
      choices: [
        { title: 'Yes', value: 'true' },
        { title: 'No', value: 'false' },
      ],
    });
  } else {
    upgradeable = options.upgradeable === 'true';
  }

  if (!options.balance) {
    promptsData.push({
      type: 'text',
      name: 'balance',
      message: 'Initial balance (will send from Giver)',
      validate: (value: string) => (isNumeric(value) ? true : 'Invalid number'),
    });
  }

  if (!options.name) {
    promptsData.push({
      type: 'text',
      name: 'name',
      message: 'Name',
      validate: (value) => !!value,
    });
  }

  if (!options.symbol) {
    promptsData.push({
      type: 'text',
      name: 'symbol',
      message: 'Symbol',
      validate: (value) => !!value,
    });
  }

  if (!options.decimals) {
    promptsData.push({
      type: 'text',
      name: 'decimals',
      message: 'Decimals',
      validate: (value) =>
        isNumeric(value) && +value <= 18 ? true : 'Invalid number',
    });
  }

  if (options.disable_mint !== 'true' && options.disable_mint !== 'false') {
    promptsData.push({
      type: 'select',
      name: 'disableMint',
      message: 'Disable mint (fixed supply)',
      choices: [
        { title: 'No', value: 'false' },
        { title: 'Yes', value: 'true' },
      ],
    });
  } else {
    disableMint = options.disable_mint === 'true';
  }

  if (
    options.disable_burn_by_root !== 'true' &&
    options.disable_burn_by_root !== 'false'
  ) {
    promptsData.push({
      type: 'select',
      name: 'disableBurnByRoot',
      message: 'Disable burn by root owner',
      choices: [
        { title: 'Yes', value: 'true' },
        { title: 'No', value: 'false' },
      ],
    });
  } else {
    disableBurnByRoot = options.disable_burn_by_root === 'true';
  }

  if (options.pause_burn !== 'true' && options.pause_burn !== 'false') {
    promptsData.push({
      type: 'select',
      name: 'pauseBurn',
      message: 'Pause burn',
      choices: [
        { title: 'No', value: 'false' },
        { title: 'Yes', value: 'true' },
      ],
    });
  } else {
    pauseBurn = options.pause_burn === 'true';
  }

  if (
    options.initial_supply_to !== '' &&
    !isValidEverAddress(options.initial_supply_to)
  ) {
    promptsData.push({
      type: 'text',
      name: 'initialSupplyTo',
      message: 'Initial supply to address (default: NO INITIAL SUPPLY)',
      validate: (value) =>
        value === '' || isValidEverAddress(value)
          ? true
          : 'Invalid EVER address',
    });
  }

  const response = await prompts(promptsData);
  const initialSupplyTo =
    options.initial_supply_to || response.initialSupplyTo || zeroAddress;

  if (!options.initial_supply && initialSupplyTo !== zeroAddress) {
    initialSupply =
      (
        await prompts({
          type: 'text',
          name: 'initialSupply',
          message: 'Initial supply (amount)',
          validate: (value: string) =>
            isNumeric(value) ? true : 'Invalid number',
        })
      ).initialSupply || '0';
  } else {
    initialSupply = options.initial_supply || '0';
  }

  const name = options.name || response.name;
  const symbol = options.symbol || response.symbol;
  const decimals = +(options.decimals || response.decimals);
  const rootOwner = options.root_owner || response.rootOwner;

  upgradeable =
    typeof upgradeable === 'boolean'
      ? upgradeable
      : response.upgradeable === 'true';

  disableMint =
    typeof disableMint === 'boolean'
      ? disableMint
      : response.disableMint === 'true';

  disableBurnByRoot =
    typeof disableBurnByRoot === 'boolean'
      ? disableBurnByRoot
      : response.disableBurnByRoot === 'true';

  pauseBurn =
    typeof pauseBurn === 'boolean' ? pauseBurn : response.pauseBurn === 'true';

  console.log(`Creating token with:`);
  console.log(`- initialSupply ${initialSupply}`);
  console.log(`- name/symbol/decimals ${name}/${symbol}/${decimals}`);

  let rootAddress: string | null = null;
  const signer = await locklift.keystore.getSigner('0');

  if (upgradeable) {
    console.log('Deploying upgradeable token...');
    const { code: TokenWalletUpgradeable } =
      locklift.factory.getContractArtifacts('TokenWalletUpgradeable');
    const { code: TokenWalletPlatform } = locklift.factory.getContractArtifacts(
      'TokenWalletPlatform',
    );

    const { contract: root } = await locklift.transactions.waitFinalized(
      locklift.deployments.deploy({
        deployConfig: {
          contract: 'TokenRootUpgradeable',
          constructorParams: {
            initialSupplyTo: initialSupplyTo,
            initialSupply: new BigNumber(initialSupply)
              .shiftedBy(decimals)
              .toFixed(),
            deployWalletValue: toNano(0.1),
            mintDisabled: disableMint,
            burnByRootDisabled: disableBurnByRoot,
            burnPaused: pauseBurn,
            remainingGasTo: zeroAddress,
          },
          initParams: {
            randomNonce_: (Math.random() * 6400) | 0,
            deployer_: zeroAddress,
            name_: name,
            symbol_: symbol,
            decimals_: decimals,
            walletCode_: TokenWalletUpgradeable,
            rootOwner_: new Address(rootOwner),
            platformCode_: TokenWalletPlatform,
          },
          value: toNano(10),
          publicKey: signer!.publicKey,
        },
        deploymentName: 'tokenRoot',
      }),
    );

    rootAddress = root.address.toString();
  } else {
    console.log('Deploying not upgradeable token...');
    const { code: TokenWallet } =
      locklift.factory.getContractArtifacts('TokenWallet');

    const { contract: root } = await locklift.transactions.waitFinalized(
      locklift.deployments.deploy({
        deployConfig: {
          contract: 'TokenRoot',
          constructorParams: {
            initialSupplyTo: initialSupplyTo,
            initialSupply: new BigNumber(initialSupply)
              .shiftedBy(decimals)
              .toFixed(),
            deployWalletValue: toNano(0.1),
            mintDisabled: disableMint,
            burnByRootDisabled: disableBurnByRoot,
            burnPaused: pauseBurn,
            remainingGasTo: zeroAddress,
          },
          initParams: {
            deployer_: zeroAddress,
            randomNonce_: (Math.random() * 6400) | 0,
            rootOwner_: new Address(rootOwner),
            name_: name,
            symbol_: symbol,
            decimals_: decimals,
            walletCode_: TokenWallet,
          },
          value: toNano(10),
          publicKey: signer!.publicKey,
        },
        deploymentName: 'tokenRoot',
      }),
    );

    rootAddress = root.address.toString();
  }

  console.log(`Token root address is: ${rootAddress} ✅`);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.log(e);
    process.exit(1);
  });
