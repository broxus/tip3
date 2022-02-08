const { Command } = require('commander');
const {
    logContract,
    isValidTonAddress,
    isNumeric,
    Migration
} = require('../utils');

const BigNumber = require('bignumber.js');
BigNumber.config({EXPONENTIAL_AT: 257});
const logger = require('mocha-logger');
const program = new Command();
const prompts = require('prompts');

const fs = require('fs');
const migration = new Migration();

async function main() {
    const keyPairs = await locklift.keys.getKeyPairs();

    const promptsData = [];

    program
        .allowUnknownOption()
        .option('-ro, --root_owner <root_owner>', 'Root owner')
        .option('-name, --name <name>', 'Name')
        .option('-symb, --symbol <symbol>', 'Symbol')
        .option('-dec, --decimals <decimals>', 'Decimals')
        .option('-ist, --initial_supply_to <initial_supply_to>', 'Initial supply to (address)')
        .option('-is, --initial_supply <initial_supply>', 'Initial supply (amount)')
        .option('-dsbm, --disable_mint <disable_mint>', 'Disable mint')
        .option('-dsbrb, --disable_burn_by_root <disable_burn_by_root>', 'Disable burn by root owner')
        .option('-pb, --pause_burn <pause_burn>', 'Pause burn');

    program.parse(process.argv);

    const options = program.opts();

    if (!isValidTonAddress(options.root_owner)) {
        promptsData.push({
            type: 'text',
            name: 'rootOwner',
            message: 'Root owner',
            validate: value => isValidTonAddress(value) ? true : 'Invalid TON address'
        })
    }

    if (!options.name) {
        promptsData.push({
            type: 'text',
            name: 'name',
            message: 'Name',
            validate: value => !!value
        })
    }

    if (!options.symbol) {
        promptsData.push({
            type: 'text',
            name: 'symbol',
            message: 'Symbol',
            validate: value => !!value
        })
    }

    if (!options.decimals) {
        promptsData.push({
            type: 'text',
            name: 'decimals',
            message: 'Decimals',
            validate: value => isNumeric(value) && (+value) <= 18 ? true : 'Invalid number'
        })
    }

    let disableMint;
    if (options.disable_mint !== 'true' && options.disable_mint !== 'false') {
        promptsData.push({
            type: 'select',
            name: 'disableMint',
            message: 'Disable mint (fixed supply)',
            choices: [
                { title: 'No', value: 'false' },
                { title: 'Yes',  value: 'true' }
            ],
        })
    } else {
        disableMint = options.disable_mint === 'true';
    }


    let disableBurnByRoot;
    if (options.disable_burn_by_root !== 'true' && options.disable_burn_by_root !== 'false') {
        promptsData.push({
            type: 'select',
            name: 'disableBurnByRoot',
            message: 'Disable burn by root owner',
            choices: [
                { title: 'Yes',  value: 'true' },
                { title: 'No', value: 'false' }
            ],
        })
    } else {
        disableBurnByRoot = options.disable_burn_by_root === 'true';
    }

    let pauseBurn;
    if (options.pause_burn !== 'true' && options.pause_burn !== 'false') {
        promptsData.push({
            type: 'select',
            name: 'pauseBurn',
            message: 'Pause burn',
            choices: [
                { title: 'No', value: 'false' },
                { title: 'Yes',  value: 'true' }
            ],
        })
    } else {
        pauseBurn = options.pause_burn === 'true';
    }

    if (options.initial_supply_to !== '' && !isValidTonAddress(options.initial_supply_to)) {
        promptsData.push({
            type: 'text',
            name: 'initialSupplyTo',
            message: 'Initial supply to address (default: NO INITIAL SUPPLY)',
            validate: value => value === '' || isValidTonAddress(value) ? true : 'Invalid TON address'
        })
    }

    const response = await prompts(promptsData);

    const initialSupplyTo = options.initial_supply_to || response.initialSupplyTo || locklift.utils.zeroAddress;
    const rootOwner = options.root_owner || response.rootOwner;
    const name = options.name || response.name;
    const symbol = options.symbol || response.symbol;
    const decimals = +(options.decimals || response.decimals);
    disableMint = typeof(disableMint) === 'boolean' ? disableMint : response.disableMint === 'true';
    disableBurnByRoot = typeof(disableBurnByRoot) === 'boolean' ? disableBurnByRoot : response.disableBurnByRoot === 'true';
    pauseBurn = typeof(pauseBurn) === 'boolean' ? pauseBurn : response.pauseBurn === 'true';

    let initialSupply;
    if (!options.initial_supply && initialSupplyTo !== locklift.utils.zeroAddress) {
        initialSupply = (await prompts({
            type: 'text',
            name: 'initialSupply',
            message: 'Initial supply (amount)',
            validate: value => isNumeric(value) ? true : 'Invalid number'
        })).initialSupply || '0';
    } else {
        initialSupply = options.initial_supply || '0';
    }

    const TokenRoot = await locklift.factory.getContract('TokenRootUpgradeable');
    const TokenWallet = await locklift.factory.getContract('TokenWalletUpgradeable');
    const TokenWalletPlatform = await locklift.factory.getContract('TokenWalletPlatform');

    let tokenRoot = await locklift.giver.deployContract({
        contract: TokenRoot,
        constructorParams: {
            initialSupplyTo: initialSupplyTo,
            initialSupply: new BigNumber(initialSupply).shiftedBy(decimals).toFixed(),
            deployWalletValue: locklift.utils.convertCrystal('0.1', 'nano'),
            mintDisabled: disableMint,
            burnByRootDisabled: disableBurnByRoot,
            burnPaused: pauseBurn,
            remainingGasTo: locklift.utils.zeroAddress
        },
        initParams: {
            randomNonce_: Math.random() * 6400 | 0,
            deployer_: locklift.utils.zeroAddress,
            name_: name,
            symbol_: symbol,
            decimals_: decimals,
            walletCode_: TokenWallet.code,
            rootOwner_: rootOwner,
            platformCode_: TokenWalletPlatform.code
        },
        keyPair: keyPairs[0],
    }, locklift.utils.convertCrystal('3', 'nano'));

    migration.store(tokenRoot, name);
    logger.log(`${name}: ${tokenRoot.address}`);

}

main()
    .then(() => process.exit(0))
    .catch(e => {
        console.log(e);
        process.exit(1);
    });
