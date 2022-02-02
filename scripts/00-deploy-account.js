const { Command } = require('commander');
const {
    logContract,
    isValidTonAddress,
    isNumeric,
    Migration
} = require('./../scripts/utils');

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
        .option('-kn, --key_number <key_number>', 'Public key number')
        .option('-b, --balance <balance>', 'Initial balance in EVERs (will send from Giver)')
        .option('-cn, --contract_name <contract_name>', 'Wallet contract name')
        .option('-cp, --contract_path <contract_path>', 'Wallet contract path');

    program.parse(process.argv);

    const options = program.opts();

    if (!options.key_number) {
        promptsData.push({
            type: 'text',
            name: 'keyNumber',
            message: 'Public key number',
            validate: value => isNumeric(value) ? true : 'Invalid number'
        })
    }

    if (!options.balance) {
        promptsData.push({
            type: 'text',
            name: 'balance',
            message: 'Initial balance (will send from Giver)',
            validate: value => isNumeric(value) ? true : 'Invalid number'
        })
    }

    if (!options.contract_path) {
        promptsData.push({
            type: 'text',
            name: 'contractPath',
            message: 'Wallet contract build path (default "build")',
            validate: value => true
        })
    }

    const response = await prompts(promptsData);

    const keyNumber = +(options.key_number || response.keyNumber);
    const balance = +(options.balance || response.balance);
    const contractPath = (options.contract_path || response.contractPath || 'build');

    let contractName;
    if (!options.contract_name) {
        contractName = (await prompts({
            type: 'select',
            name: 'contractName',
            message: 'Select wallet contract name',
            choices: [...new Set(fs.readdirSync(contractPath)
                .map(o => o.split('.')[0]))]
                .filter((value, index, self) => self.indexOf(value) === index)
                .map(e => new Object({title: e, value: e}))
        })).contractName;
    } else {
        contractName = options.contract_name;
    }

    const Account = await locklift.factory.getAccount(contractName, contractPath);

    let account = await locklift.giver.deployContract({
        contract: Account,
        constructorParams: {},
        initParams: {
            _randomNonce: (contractName === 'Wallet' ? Math.random() * 6400 | 0 : null),
        },
        keyPair: keyPairs[keyNumber],
    }, locklift.utils.convertCrystal(balance, 'nano'));
    const name = `Wallet${keyNumber}`;
    migration.store(account, name);
    logger.log(`${name}: ${account.address}`);
}

main()
    .then(() => process.exit(0))
    .catch(e => {
        console.log(e);
        process.exit(1);
    });
