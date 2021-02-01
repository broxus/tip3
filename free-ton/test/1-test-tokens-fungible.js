require('dotenv').config({path: './../env/freeton.env'});

const logger = require('mocha-logger');
const assert = require('assert');
const freeton = require('ton-testing-suite');
const BigNumber = require('bignumber.js');

const ZERO_ADDRESS = '0:0000000000000000000000000000000000000000000000000000000000000000';

let RootTokenContractExternalOwner;
let RootTokenContractInternalOwner;
let RootTokenContractInternalOwnerTest;
let TONTokenWalletInternalOwnerTest;
let SelfDeployedWallet;
let DeployEmptyWalletFor;
let TONTokenWalletHack;
let fw0address;
let FooWallet0;
let fw1address;
let FooWallet1;
let fw2address;
let FooWallet2;
let bwInternalAddress;
let BarWalletInternal;
let bw3address;
let BarWallet3;
let bw6address;
let BarWallet6;


const tonWrapper = new freeton.TonWrapper({
    network: process.env.NETWORK,
    seed: process.env.SEED,
    randomTruffleNonce: Boolean(process.env.RANDOM_TRUFFLE_NONCE),
    config: {
        messageExpirationTimeout: 600000
    }
});


describe('Test Fungible Tokens', function () {
    this.timeout(600000);

    before(async function () {
        await tonWrapper.setup();

        RootTokenContractExternalOwner = await freeton.requireContract(tonWrapper, 'RootTokenContract');
        RootTokenContractInternalOwner = await freeton.requireContract(tonWrapper, 'RootTokenContract');
        RootTokenContractInternalOwnerTest = await freeton.requireContract(tonWrapper, 'RootTokenContractInternalOwnerTest');
        TONTokenWalletInternalOwnerTest = await freeton.requireContract(tonWrapper, 'TONTokenWalletInternalOwnerTest');
        SelfDeployedWallet = await freeton.requireContract(tonWrapper, 'TONTokenWallet');
        TONTokenWalletHack = await freeton.requireContract(tonWrapper, 'TONTokenWalletHack');
        DeployEmptyWalletFor = await freeton.requireContract(tonWrapper, 'DeployEmptyWalletFor');
        await RootTokenContractExternalOwner.loadMigration('RootTokenContractExternalOwner');
        await RootTokenContractInternalOwner.loadMigration('RootTokenContractInternalOwner');
        await RootTokenContractInternalOwnerTest.loadMigration();
        await TONTokenWalletInternalOwnerTest.loadMigration();
        await SelfDeployedWallet.loadMigration();
        await TONTokenWalletHack.loadMigration();
        await DeployEmptyWalletFor.loadMigration();

        logger.log(`RootTokenContractExternalOwner address: ${RootTokenContractExternalOwner.address}`);
        logger.log(`RootTokenContractInternalOwner address: ${RootTokenContractInternalOwner.address}`);
        logger.log(`RootTokenContractInternalOwnerTest address: ${RootTokenContractInternalOwnerTest.address}`);
        logger.log(`TONTokenWalletInternalOwnerTest address: ${TONTokenWalletInternalOwnerTest.address}`);
        logger.log(`SelfDeployedWallet (FooWallet#4) address: ${SelfDeployedWallet.address}`);
        logger.log(`TONTokenWalletHack address: ${TONTokenWalletHack.address}`);
        logger.log(`DeployEmptyWalletFor address: ${DeployEmptyWalletFor.address}`);
    });

    describe('Test deploy wallets', async function () {
        it('Internal call RootTokenContractExternalOwner.deployEmptyWallet by DeployEmptyWalletFor', async () => {
            logger.log('######################################################');
            logger.log('Deploy FooWallet#0 using DeployEmptyWalletFor contract');

            const rootStartGrams = await tonWrapper.getBalance(RootTokenContractExternalOwner.address);
            const deployEmptyWalletForStartGrams = await tonWrapper.getBalance(DeployEmptyWalletFor.address);

            await DeployEmptyWalletFor.run(
                'deployEmptyWalletFor',
                {
                    pubkey: `0x${tonWrapper.keys[0].public}`,
                    addr: ZERO_ADDRESS
                },
                tonWrapper.keys[0]
            ).catch(e => console.log(e));

            fw0address = await RootTokenContractExternalOwner.runLocal('getWalletAddress', {
                wallet_public_key_: `0x${tonWrapper.keys[0].public}`,
                owner_address_: ZERO_ADDRESS,
            });

            FooWallet0 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                fw0address
            );

            const fw0balance = await FooWallet0.runLocal('balance', {});

            const rootEndGrams = await tonWrapper.getBalance(RootTokenContractExternalOwner.address);
            const deployEmptyWalletForEndGrams = await tonWrapper.getBalance(DeployEmptyWalletFor.address);
            const fw0EndGrams = await tonWrapper.getBalance(FooWallet0.address);
            const totalGas = new BigNumber(rootStartGrams)
                .plus(deployEmptyWalletForStartGrams)
                .minus(rootEndGrams)
                .minus(deployEmptyWalletForEndGrams)
                .minus(fw0EndGrams)
                .div(1000000000)
                .toNumber();

            logger.log(`RootTokenContractExternalOwner GRAMS change:
                ${new BigNumber(rootEndGrams).minus(rootStartGrams).div(1000000000).toFixed(9)} TON`);

            logger.log(`DeployEmptyWalletFor GRAMS change:
                ${new BigNumber(deployEmptyWalletForEndGrams).minus(deployEmptyWalletForStartGrams).div(1000000000).toFixed(9)} TON`);

            logger.log(`FooWallet#0:
                address = ${fw0address},
                tokens = ${fw0balance} FOO,
                grams = ${new BigNumber(fw0EndGrams).div(1000000000).toFixed(9)} TON`);

            logger.log(`GAS used: ${totalGas} TON`);

            assert.ok(fw0address);
        });

        it('External call RootTokenContractExternalOwner.deployWallet by owner #1', async () => {
            logger.log('######################################################');
            logger.log('Deploy FooWallet#1 user with 10.000 tokens. (grams= 1 ton)');

            const rootStartGrams = await tonWrapper.getBalance(RootTokenContractExternalOwner.address);

            await RootTokenContractExternalOwner.run(
                'deployWallet',
                {
                    tokens: 10000,
                    grams: freeton.utils.convertCrystal('1', 'nano'),
                    wallet_public_key_: `0x${tonWrapper.keys[1].public}`,
                    owner_address_: ZERO_ADDRESS,
                    gas_back_address: ZERO_ADDRESS,
                },
                tonWrapper.keys[0]
            ).catch(e => console.log(e));

            fw1address = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[1].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            FooWallet1 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                fw1address
            );

            const fw1balance = await FooWallet1.runLocal('balance', {});

            const rootEndGrams = await tonWrapper.getBalance(RootTokenContractExternalOwner.address);
            const fw1EndGrams = await tonWrapper.getBalance(FooWallet1.address);

            const totalGas = new BigNumber(rootStartGrams)
                .minus(rootEndGrams)
                .minus(fw1EndGrams)
                .div(1000000000)
                .toNumber();

            logger.log(`RootTokenContractExternalOwner GRAMS change:
                ${new BigNumber(rootEndGrams).minus(rootStartGrams).div(1000000000).toFixed(9)} TON`);

            logger.log(`FooWallet#1:
                address = ${fw1address},
                balance = ${fw1balance} FOO,
                grams = ${new BigNumber(fw1EndGrams).div(1000000000).toFixed(9)} TON`);

            logger.log(`GAS used: ${totalGas} TON`);

            assert.ok(fw1address);
        });

        it('External call RootTokenContractExternalOwner.deployWallet by owner #2', async () => {
            logger.log('######################################################');
            logger.log('Deploy FooWallet#2 with 20.000 tokens. (grams = 1 ton)');

            const rootStartGrams = await tonWrapper.getBalance(RootTokenContractExternalOwner.address);

            await RootTokenContractExternalOwner.run(
                'deployWallet',
                {
                    tokens: 20000,
                    grams: freeton.utils.convertCrystal('1', 'nano'),
                    wallet_public_key_: `0x${tonWrapper.keys[2].public}`,
                    owner_address_: ZERO_ADDRESS,
                    gas_back_address: ZERO_ADDRESS,
                },
                tonWrapper.keys[0]
            ).catch(e => console.log(e));

            fw2address = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[2].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            FooWallet2 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                fw2address
            );

            const fw2balance = await FooWallet2.runLocal('balance', {});

            const rootEndGrams = await tonWrapper.getBalance(RootTokenContractExternalOwner.address);
            const fw2EndGrams = await tonWrapper.getBalance(FooWallet2.address);

            const totalGas = new BigNumber(rootStartGrams)
                .minus(rootEndGrams)
                .minus(fw2EndGrams)
                .div(1000000000)
                .toNumber();

            logger.log(`RootTokenContractExternalOwner GRAMS change:
                ${new BigNumber(rootEndGrams).minus(rootStartGrams).div(1000000000).toFixed(9)} TON`);

            logger.log(`FooWallet#2:
                address = ${fw2address},
                balance = ${fw2balance} FOO,
                grams = ${new BigNumber(fw2EndGrams).div(1000000000).toFixed(9)} TON`);

            logger.log(`GAS used: ${totalGas} TON`);

            assert.ok(fw2address);
        });

        it('Internal call RootTokenContractInternalOwner.deployEmptyWallet by TONTokenWalletInternalOwnerTest', async () => {
            logger.log('######################################################');
            logger.log('Deploy BarWallet#Internal');

            const tokensInternalOwnerStartGrams = await tonWrapper.getBalance(TONTokenWalletInternalOwnerTest.address);
            const rootStartGrams = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);

            await TONTokenWalletInternalOwnerTest.run(
                'deployEmptyWallet',
                {
                    root_address: RootTokenContractInternalOwner.address,
                    grams: freeton.utils.convertCrystal('0.02', 'nano')
                },
                tonWrapper.keys[5]
            ).catch(e => console.log(e));

            bwInternalAddress = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x0`,
                    owner_address_: TONTokenWalletInternalOwnerTest.address,
                });

            BarWalletInternal = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                bwInternalAddress
            );
            const bwInternalBalance = await BarWalletInternal.runLocal('balance', {});

            const tokensInternalOwnerEndGrams = await tonWrapper.getBalance(TONTokenWalletInternalOwnerTest.address);
            const rootEndGrams = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);
            const bwInternalEndGrams = await tonWrapper.getBalance(BarWalletInternal.address);

            const totalGas = new BigNumber(tokensInternalOwnerStartGrams)
                .plus(rootStartGrams)
                .minus(tokensInternalOwnerEndGrams)
                .minus(rootEndGrams)
                .minus(bwInternalEndGrams)
                .div(1000000000)
                .toNumber();

            logger.log(`TONTokenWalletInternalOwnerTest GRAMS change:
                ${new BigNumber(tokensInternalOwnerEndGrams).minus(tokensInternalOwnerStartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`RootTokenContractInternalOwner GRAMS change:
                ${new BigNumber(rootEndGrams).minus(rootStartGrams).div(1000000000).toFixed(9)} TON`);

            logger.log(`BarWallet#Internal:
                address = ${bwInternalAddress},
                tokens = ${bwInternalBalance} BAR,
                grams = ${new BigNumber(bwInternalEndGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`GAS used: ${totalGas} TON`);
            assert.ok(bwInternalAddress);
        });

        it('Internal call RootTokenContractInternalOwner.deployWallet by RootTokenContractInternalOwnerTest #1', async () => {
            logger.log('######################################################');
            logger.log(`Deploy BarWallet#3 with 30000 BAR`);

            const rootStartGrams = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);
            const rootOwnerStartGrams = await tonWrapper.getBalance(RootTokenContractInternalOwnerTest.address);

            await RootTokenContractInternalOwnerTest.run(
                'deployWallet',
                {
                    tokens: 30000,
                    grams: freeton.utils.convertCrystal('2.5', 'nano'),
                    pubkey: `0x${tonWrapper.keys[3].public}`,
                    addr: ZERO_ADDRESS,
                },
                tonWrapper.keys[0]
            ).catch(e => console.log(e));

            bw3address = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[3].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            BarWallet3 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                bw3address
            );
            const bw3balance = await BarWallet3.runLocal('balance', {});

            const bw3EndGrams = await tonWrapper.getBalance(BarWallet3.address);
            const rootEndGrams = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);
            const rootOwnerEndGrams = await tonWrapper.getBalance(RootTokenContractInternalOwnerTest.address);

            const totalGas = new BigNumber(rootStartGrams)
                .plus(rootOwnerStartGrams)
                .minus(rootEndGrams)
                .minus(rootOwnerEndGrams)
                .minus(bw3EndGrams)
                .div(1000000000)
                .toNumber();

            logger.log(`RootTokenContractInternalOwnerTest GRAMS change:
                ${new BigNumber(rootOwnerEndGrams).minus(rootOwnerStartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`RootTokenContractInternalOwner GRAMS change:
                ${new BigNumber(rootEndGrams).minus(rootStartGrams).div(1000000000).toFixed(9)} TON`);

            logger.log(`BarWallet#3:
                address = ${bw3address},
                balance = ${bw3balance} BAR,
                grams = ${new BigNumber(bw3EndGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`GAS used: ${totalGas} TON`);
            assert.ok(bw3address);
        });

        it('Internal call RootTokenContractInternalOwner.deployWallet by RootTokenContractInternalOwnerTest #2', async () => {
            logger.log('######################################################');
            logger.log(`Deploy BarWallet#6 with 60000 BAR`);

            const rootStartGrams = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);
            const rootOwnerStartGrams = await tonWrapper.getBalance(RootTokenContractInternalOwnerTest.address);

            await RootTokenContractInternalOwnerTest.run(
                'deployWallet',
                {
                    tokens: 60000,
                    grams: freeton.utils.convertCrystal('2.5', 'nano'),
                    pubkey: `0x${tonWrapper.keys[6].public}`,
                    addr: ZERO_ADDRESS
                },
                tonWrapper.keys[0]
            ).catch(e => console.log(e));

            bw6address = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[6].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            BarWallet6 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                bw6address
            );

            const bw6balance = await BarWallet6.runLocal('balance', {});

            const bw6EndGrams = await tonWrapper.getBalance(BarWallet6.address);
            const rootEndGrams = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);
            const rootOwnerEndGrams = await tonWrapper.getBalance(RootTokenContractInternalOwnerTest.address);

            const totalGas = new BigNumber(rootStartGrams)
                .plus(rootOwnerStartGrams)
                .minus(rootEndGrams)
                .minus(rootOwnerEndGrams)
                .minus(bw6EndGrams)
                .div(1000000000)
                .toNumber();

            logger.log(`RootTokenContractInternalOwnerTest GRAMS change:
                ${new BigNumber(rootOwnerEndGrams).minus(rootOwnerStartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`RootTokenContractInternalOwner GRAMS change:
                ${new BigNumber(rootEndGrams).minus(rootStartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`BarWallet#6:
                address = ${bw6address},
                balance = ${bw6balance} BAR,
                grams = ${new BigNumber(bw6EndGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`GAS used: ${totalGas} TON`);
            assert.ok(bw6address);
        });

        it('Check SelfDeployedWallet address (must be equals RootTokenContractExternalOwner.getWalletAddress(...))', async () => {
            logger.log('######################################################');
            logger.log('Check SelfDeployedWallet address');
            const expectedAddress = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[4].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            logger.log(`Expected FooWallet#4 address: ${expectedAddress}`);
            logger.log(`Actual SelfDeployedWallet address: ${SelfDeployedWallet.address}`);
            assert.equal(expectedAddress, SelfDeployedWallet.address, 'Wallets address not equals');
        });

        it('Check address for contract with changed code (must be NOT equals RootTokenContractExternalOwner.getWalletAddress(...))', async () => {
            logger.log('######################################################');
            logger.log('Check TONTokenWalletHack address');
            const expectedAddress = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[9].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            logger.log(`Expected FooWallet#9 address: ${expectedAddress}`);
            logger.log(`Actual TONTokenWalletHack address: ${TONTokenWalletHack.address}`);
            assert.notEqual(expectedAddress, TONTokenWalletHack.address, 'Wallets address equals');
        });
    });

    describe('Test BarWallet#Internal target_gas_balance on internalTransfer', async function () {
        it('Transfer tokens to address must compensate gas balance to `target_gas_balance`', async () => {
            logger.log('######################################################');
            logger.log('BarWallet#6 transfer 1000 to BarWallet#Internal');

            bw6address = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[6].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            BarWallet6 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                bw6address
            );

            bwInternalAddress = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x0`,
                    owner_address_: TONTokenWalletInternalOwnerTest.address,
                });

            BarWalletInternal = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                bwInternalAddress
            );

            const bwInternalStartBalance = await BarWalletInternal.runLocal('balance', {});
            const bw6StartBalance = await BarWallet6.runLocal('balance', {});

            const bwInternalStartGrams = await tonWrapper.getBalance(BarWalletInternal.address);
            const bw6StartGrams = await tonWrapper.getBalance(BarWallet6.address);

            logger.log(`BarWallet#6 start balance: ${bw6StartBalance} BAR`);
            logger.log(`BarWallet#Internal start balance: ${bwInternalStartBalance} BAR`);

            await BarWallet6.run(
                'transfer',
                {
                    tokens: 1000,
                    to: bwInternalAddress,
                    grams: freeton.utils.convertCrystal('0.5', 'nano')
                },
                tonWrapper.keys[6]
            ).catch(e => console.log(e));

            const bwInternalEndBalance = await BarWalletInternal.runLocal('balance', {});
            const bw6EndBalance = await BarWallet6.runLocal('balance', {});

            const bwInternalEndGrams = await tonWrapper.getBalance(BarWalletInternal.address);
            const bw6EndGrams = await tonWrapper.getBalance(BarWallet6.address);

            logger.log(`BarWallet#6 end balance: ${bw6EndBalance} BAR`);
            logger.log(`BarWallet#Internal end balance: ${bwInternalEndBalance} BAR`);

            const bwInternalEndGramsChange =  new BigNumber(bwInternalEndGrams).minus(bwInternalStartGrams).div(1000000000);

            logger.log(`BarWallet#6 GRAMS change:
                ${new BigNumber(bw6EndGrams).minus(bw6StartGrams).div(1000000000).toFixed(9)}`);

            logger.log(`BarWallet#Internal GRAMS change: ${bwInternalEndGramsChange.toFixed(9)}`);

            assert.equal(bwInternalEndGramsChange.gt(0.07), true, 'BarWallet#Internal GRAMS change less then +0.07');

        });

    });

    describe('Test mint/burn', async function () {
        it('Internal call RootTokenContractInternalOwner.mint by owner', async () => {
            logger.log('######################################################');
            logger.log('Mint 100.000 tokens for BarWallet#Internal');
            const startBalance = await BarWalletInternal.runLocal('balance', {});
            const startTotalSupply = await RootTokenContractInternalOwner.runLocal('total_supply', {});
            logger.log(`Start balance of BarWallet#Internal: ${startBalance} BAR`);
            logger.log(`Start total supply: ${startTotalSupply} BAR`);

            const bwInternalStartGrams = await tonWrapper.getBalance(BarWalletInternal.address);
            const rootOwnerStartGrams = await tonWrapper.getBalance(RootTokenContractInternalOwnerTest.address);
            const rootStartGrams = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);

            await RootTokenContractInternalOwnerTest.run(
                'mint',
                {
                    tokens: 100000,
                    addr: bwInternalAddress
                },
                tonWrapper.keys[0]
            ).catch(e => console.log(e));

            const endBalance = await BarWalletInternal.runLocal('balance', {});
            const endTotalSupply = await RootTokenContractInternalOwner.runLocal('total_supply', {});
            logger.log(`End balance of barWalletInternal: ${endBalance} BAR`);
            logger.log(`End total supply: ${endTotalSupply} BAR`);

            const bwInternalEndGrams = await tonWrapper.getBalance(BarWalletInternal.address);
            const rootOwnerEndGrams = await tonWrapper.getBalance(RootTokenContractInternalOwnerTest.address);
            const rootEndGrams = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);

            const totalGas = new BigNumber(rootStartGrams)
                .plus(rootOwnerStartGrams)
                .plus(bwInternalStartGrams)
                .minus(rootEndGrams)
                .minus(rootOwnerEndGrams)
                .minus(bwInternalEndGrams)
                .div(1000000000)
                .toNumber();

            logger.log(`RootTokenContractInternalOwner GRAMS change:
                ${new BigNumber(rootEndGrams).minus(rootStartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`RootTokenContractInternalOwnerTest GRAMS change:
                ${new BigNumber(rootOwnerEndGrams).minus(rootOwnerStartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`BarWallet#Internal GRAMS change:
                ${new BigNumber(bwInternalEndGrams).minus(bwInternalStartGrams).div(1000000000).toFixed(9)} TON`);

            logger.log(`GAS used: ${totalGas} TON`);

            assert.equal(
                new BigNumber(startBalance).plus(100000).toNumber(),
                new BigNumber(endBalance).toNumber(),
                'Balance wrong');
            assert.equal(
                new BigNumber(startTotalSupply).plus(100000).toNumber(),
                new BigNumber(endTotalSupply).toNumber(),
                'Total supply wrong');
        });

        it('Internal call RootTokenContract.withdrawExtraGas from RootTokenContractInternalOwnerTest', async () => {
            logger.log('######################################################');
            logger.log('Check current balance and details');

            const startRootBalance = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);
            const startRootOwnerBalance = await tonWrapper.getBalance(RootTokenContractInternalOwnerTest.address);

            const startDetails = await RootTokenContractInternalOwner.runLocal('getDetails', {});

            logger.log(`Start RootTokenContractInternalOwner balance: ${startRootBalance.div(1000000000).toFixed(9)} TON`);
            logger.log(`Start RootTokenContractInternalOwnerTest balance: ${startRootOwnerBalance.div(1000000000).toFixed(9)} TON`);
            logger.log(`RootTokenContractInternalOwner start_gas_balance_ = ${startDetails.start_gas_balance.div(1000000000).toFixed(9)} TON`);

            logger.log(`Send 1 TON from RootTokenContractInternalOwnerTest to RootTokenContractInternalOwner`);

            await RootTokenContractInternalOwnerTest.run(
                'sendGramsToRoot',
                {
                    grams: freeton.utils.convertCrystal('1', 'nano')
                },
                tonWrapper.keys[0]
            ).catch(e => console.log(e));

            const currentRootBalance = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);
            const currentRootOwnerBalance = await tonWrapper.getBalance(RootTokenContractInternalOwnerTest.address);

            logger.log(`Current RootTokenContractInternalOwner balance: ${currentRootBalance.div(1000000000).toFixed(9)} TON`);
            logger.log(`Current RootTokenContractInternalOwnerTest balance: ${currentRootOwnerBalance.div(1000000000).toFixed(9)} TON`);

            logger.log(`Call RootTokenContract.withdrawExtraGas`);

            await RootTokenContractInternalOwnerTest.run(
                'testWithdrawExtraGas',
                {},
                tonWrapper.keys[0]
            ).catch(e => console.log(e));

            const endRootBalance = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);
            const endRootOwnerBalance = await tonWrapper.getBalance(RootTokenContractInternalOwnerTest.address);
            logger.log(`End RootTokenContractInternalOwner balance: ${endRootBalance.div(1000000000).toFixed(9)} TON`);
            logger.log(`End RootTokenContractInternalOwnerTest balance: ${endRootOwnerBalance.div(1000000000).toFixed(9)} TON`);

            assert.ok(endRootOwnerBalance.gte(currentRootOwnerBalance));
        });

        it('External call TONTokenWallet.burnByOwner', async () => {
            logger.log('######################################################');
            logger.log('BurnByOwner 5.000 tokens from BarWallet#3');

            bw3address = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[3].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            BarWallet3 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                bw3address
            );

            const startBalance = await BarWallet3.runLocal('balance', {});
            const startTotalSupply = await RootTokenContractInternalOwner.runLocal('total_supply', {});
            const startBurnedCount = await RootTokenContractInternalOwnerTest.runLocal('getBurnedCount', {});
            const startLatestPayload = await RootTokenContractInternalOwnerTest.runLocal('getLatestPayload', {});

            logger.log(`Start balance of BarWallet#3: ${startBalance} BAR`);
            logger.log(`Start total supply: ${startTotalSupply} BAR`);
            logger.log(`Start burned count: ${startBurnedCount} BAR`);
            logger.log(`Start payload: ${startLatestPayload}`);

            const bw3StartGrams = await tonWrapper.getBalance(BarWallet3.address);
            const rootOwnerStartGrams = await tonWrapper.getBalance(RootTokenContractInternalOwnerTest.address);
            const rootStartGrams = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);

            await BarWallet3.run(
                'burnByOwner',
                {
                    tokens: 5000,
                    grams: freeton.utils.convertCrystal('1.5', 'nano'),
                    callback_address: RootTokenContractInternalOwnerTest.address,
                    callback_payload: startLatestPayload
                },
                tonWrapper.keys[3]
            ).catch(e => console.log(e));

            const endBalance = await BarWallet3.runLocal('balance', {});
            const endTotalSupply = await RootTokenContractInternalOwner.runLocal('total_supply', {});
            const endBurnedCount = await RootTokenContractInternalOwnerTest.runLocal('getBurnedCount', {});
            const endLatestPayload = await RootTokenContractInternalOwnerTest.runLocal('getLatestPayload', {});
            logger.log(`End balance of BarWallet#3: ${endBalance} BAR`);
            logger.log(`End total supply: ${endTotalSupply} BAR`);
            logger.log(`End burned count: ${endBurnedCount} BAR`);
            logger.log(`End payload: ${endLatestPayload}`);

            const bw3EndGrams = await tonWrapper.getBalance(BarWallet3.address);
            const rootOwnerEndGrams = await tonWrapper.getBalance(RootTokenContractInternalOwnerTest.address);
            const rootEndGrams = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);

            const totalGas = new BigNumber(rootStartGrams)
                .plus(rootOwnerStartGrams)
                .plus(bw3StartGrams)
                .minus(rootEndGrams)
                .minus(rootOwnerEndGrams)
                .minus(bw3EndGrams)
                .div(1000000000)
                .toNumber();

            logger.log(`RootTokenContractInternalOwner GRAMS change: 
                ${new BigNumber(rootEndGrams).minus(rootStartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`RootTokenContractInternalOwnerTest GRAMS change: 
                ${new BigNumber(rootOwnerEndGrams).minus(rootOwnerStartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`BarWallet3 GRAMS change: 
                ${new BigNumber(bw3EndGrams).minus(bw3StartGrams).div(1000000000).toFixed(9)} TON`);

            logger.log(`GAS used: ${totalGas} TON`);

            assert.equal(
                new BigNumber(startBalance).minus(5000).toNumber(),
                new BigNumber(endBalance).toNumber(),
                'Balance wrong');
            assert.equal(
                new BigNumber(startTotalSupply).minus(5000).toNumber(),
                new BigNumber(endTotalSupply).toNumber(),
                'Total supply wrong');
            assert.equal(
                new BigNumber(startBurnedCount).plus(5000).toNumber(),
                new BigNumber(endBurnedCount).toNumber(),
                'Burned count wrong');
        });

        it('Internal call RootTokenContractInternalOwnerTest.burnMyTokens by TONTokenWalletInternalOwnerTest', async () => {
            logger.log('######################################################');
            logger.log('BurnByRoot 50.000 tokens from BarWallet#Internal');
            bwInternalAddress = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x0`,
                    owner_address_: TONTokenWalletInternalOwnerTest.address,
                });

            BarWalletInternal = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                bwInternalAddress
            );

            const startBalance = await BarWalletInternal.runLocal('balance', {});
            const startTotalSupply = await RootTokenContractInternalOwner.runLocal('total_supply', {});
            const startBurnedCount = await RootTokenContractInternalOwnerTest.runLocal('getBurnedCount', {});
            const startLatestPayload = await RootTokenContractInternalOwnerTest.runLocal('getLatestPayload', {});

            logger.log(`Start balance of BarWallet#Internal: ${startBalance} BAR`);
            logger.log(`Start total supply: ${startTotalSupply}`);
            logger.log(`Start burned count: ${startBurnedCount}`);
            logger.log(`Start payload: ${startLatestPayload}`);

            const tokensInternalOwnerStartGrams = await tonWrapper.getBalance(TONTokenWalletInternalOwnerTest.address);
            const bwInternalStartGrams = await tonWrapper.getBalance(BarWalletInternal.address);
            const rootOwnerStartGrams = await tonWrapper.getBalance(RootTokenContractInternalOwnerTest.address);
            const rootStartGrams = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);

            await TONTokenWalletInternalOwnerTest.run(
                'burnMyTokens',
                {
                    tokens: 50000,
                    grams: freeton.utils.convertCrystal('3', 'nano'),
                    burner_address: RootTokenContractInternalOwnerTest.address,
                    callback_address: RootTokenContractInternalOwnerTest.address,
                    ethereum_address: 'c227CE9EdCc60a725DE66A1132171a22ae62a64F'
                },
                tonWrapper.keys[5]
            ).catch(e => console.log(e));

            const endBalance = await BarWalletInternal.runLocal('balance', {});
            const endTotalSupply = await RootTokenContractInternalOwner.runLocal('total_supply', {});
            const endBurnedCount = await RootTokenContractInternalOwnerTest.runLocal('getBurnedCount', {});
            const endLatestPayload = await RootTokenContractInternalOwnerTest.runLocal('getLatestPayload', {});
            logger.log(`End balance of BarWallet#Internal: ${endBalance} BAR`);
            logger.log(`End total supply: ${endTotalSupply} BAR`);
            logger.log(`End burned count: ${endBurnedCount} BAR `);
            logger.log(`End payload: ${endLatestPayload}`);

            const tokensInternalOwnerEndGrams = await tonWrapper.getBalance(TONTokenWalletInternalOwnerTest.address);
            const bwInternalEndGrams = await tonWrapper.getBalance(BarWalletInternal.address);
            const rootOwnerEndGrams = await tonWrapper.getBalance(RootTokenContractInternalOwnerTest.address);
            const rootEndGrams = await tonWrapper.getBalance(RootTokenContractInternalOwner.address);

            const totalGas = new BigNumber(rootStartGrams)
                .plus(rootOwnerStartGrams)
                .plus(bwInternalStartGrams)
                .plus(tokensInternalOwnerStartGrams)
                .minus(rootEndGrams)
                .minus(rootOwnerEndGrams)
                .minus(bwInternalEndGrams)
                .minus(tokensInternalOwnerEndGrams)
                .div(1000000000)
                .toNumber();

            logger.log(`TONTokenWalletInternalOwnerTest GRAMS change: 
                ${new BigNumber(tokensInternalOwnerEndGrams).minus(tokensInternalOwnerStartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`BarWalletInternal GRAMS change: 
                ${new BigNumber(bwInternalEndGrams).minus(bwInternalStartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`RootTokenContractInternalOwnerTest GRAMS change: 
                ${new BigNumber(rootOwnerEndGrams).minus(rootOwnerStartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`RootTokenContractInternalOwner GRAMS change: 
                ${new BigNumber(rootEndGrams).minus(rootStartGrams).div(1000000000).toFixed(9)} TON`);

            logger.log(`GAS used: ${totalGas} TON`);

            assert.equal(
                new BigNumber(startBalance).minus(50000).toNumber(),
                new BigNumber(endBalance).toNumber(),
                'Balance wrong');
            assert.equal(
                new BigNumber(startTotalSupply).minus(50000).toNumber(),
                new BigNumber(endTotalSupply).toNumber(),
                'Total supply wrong');
            assert.equal(
                new BigNumber(startBurnedCount).plus(50000).toNumber(),
                new BigNumber(endBurnedCount).toNumber(),
                'Burned count wrong');
        });

        it('onBounce for RootTokenContractExternalOwner.mint must decrease total supply', async () => {
            logger.log('######################################################');
            logger.log('Mint 10.000 tokens for non exists address (BarWallet#44)');

            const startTotalSupply = await RootTokenContractExternalOwner.runLocal('total_supply', {});
            logger.log(`Start total supply: ${startTotalSupply} FOO`);

            const rootStartGrams = await tonWrapper.getBalance(RootTokenContractExternalOwner.address);

            const notExistsWalletAddress = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[44].public}`,
                    owner_address_: ZERO_ADDRESS,
                });
            logger.log('RUN RootTokenContractExternalOwner.mint. That increase total supply.');
            logger.log(`Current total supply: ${new BigNumber(startTotalSupply).plus(10000).toNumber()} FOO`);
            await RootTokenContractExternalOwner.run(
                'mint',
                {
                    to: notExistsWalletAddress,
                    tokens: 10000
                },
                tonWrapper.keys[0]
            ).catch(e => console.log(e));

            const endTotalSupply = await RootTokenContractExternalOwner.runLocal('total_supply', {});
            logger.log(`End total supply: ${endTotalSupply} FOO`);

            const rootEndGrams = await tonWrapper.getBalance(RootTokenContractExternalOwner.address);

            logger.log(`RootTokenContractExternalOwner GRAMS change:
                ${new BigNumber(rootEndGrams).minus(rootStartGrams).div(1000000000).toFixed(9)} TON`);

            assert.equal(
                new BigNumber(startTotalSupply).toNumber(),
                new BigNumber(endTotalSupply).toNumber(),
                'Total supply wrong');
        });
    });

    describe('Trying to hack', async function () {
        it('Internal call TONTokenWallet.internal_transfer by TONTokenWalletHack (must be failed)', async () => {
            logger.log('######################################################');
            logger.log('TONTokenWalletHack calls TONTokenWallet.internal_transfer');
            const startBalance = await SelfDeployedWallet.runLocal('balance', {});

            logger.log(`Start balance for FooWallet#4: ${startBalance} FOO`);

            await TONTokenWalletHack.run(
                'mint',
                {
                    tokens: 1000,
                    to: SelfDeployedWallet.address,
                    grams: freeton.utils.convertCrystal('0.2', 'nano')
                },
                tonWrapper.keys[9]
            ).catch(e => console.log(e));

            const endBalance = await SelfDeployedWallet.runLocal('balance', {});
            logger.log(`End balance for FooWallet#4: ${endBalance} FOO`);
            assert.equal(new BigNumber(startBalance).toNumber(), new BigNumber(endBalance).toNumber(), 'Exploit expected');
        });
    });

    describe('Test transfer', async function () {

        it('Simple transfer (external call TONTokenWallet.transfer)', async () => {
            logger.log('######################################################');
            logger.log('Transfer 1000 tokens from FooWallet#2 to FooWallet#1');
            fw1address = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[1].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            FooWallet1 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                fw1address
            );

            fw2address = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[2].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            FooWallet2 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                fw2address
            );

            const w1StartBalance = await FooWallet1.runLocal('balance', {});
            const w2StartBalance = await FooWallet2.runLocal('balance', {});
            logger.log(`FooWallet#1 start balance: ${w1StartBalance}`);
            logger.log(`FooWallet#2 start balance: ${w2StartBalance}`);

            const fw1StartGrams = await tonWrapper.getBalance(FooWallet1.address);
            const fw2StartGrams = await tonWrapper.getBalance(FooWallet2.address);

            await FooWallet2.run(
                'transfer',
                {
                    tokens: 1000,
                    to: fw1address,
                    grams: freeton.utils.convertCrystal('0.3', 'nano')
                },
                tonWrapper.keys[2]
            ).catch(e => console.log(e));

            const fw1EndBalance = await FooWallet1.runLocal('balance', {});
            const fw2EndBalance = await FooWallet2.runLocal('balance', {});
            logger.log(`FooWallet#1 end balance: ${fw1EndBalance} FOO`);
            logger.log(`FooWallet#2 end balance: ${fw2EndBalance} FOO`);

            const fw1EndGrams = await tonWrapper.getBalance(FooWallet1.address);
            const fw2EndGrams = await tonWrapper.getBalance(FooWallet2.address);
            logger.log(`FooWallet#1 GRAMS change:
                ${new BigNumber(fw1EndGrams).minus(fw1StartGrams).div(1000000000).toFixed(9)}`);
            logger.log(`FooWallet#2 GRAMS change:
                ${new BigNumber(fw2EndGrams).minus(fw2StartGrams).div(1000000000).toFixed(9)}`);

            assert.equal(new BigNumber(fw1EndBalance).toNumber(), new BigNumber(w1StartBalance).plus(1000).toNumber(), 'FooWallet#1 balance wrong');
            assert.equal(new BigNumber(fw2EndBalance).toNumber(), new BigNumber(w2StartBalance).minus(1000).toNumber(), 'FooWallet#2 balance wrong');

        });

        it('Transfer to self deployed wallet (external call TONTokenWallet.transfer)', async () => {
            logger.log('######################################################');
            logger.log('Transfer 1000 tokens from FooWallet#1 to self deployed FooWallet#4');
            fw1address = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[1].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            FooWallet1 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                fw1address
            );

            const fw1StartGrams = await tonWrapper.getBalance(FooWallet1.address);
            const selfDeployWalletStartGrams = await tonWrapper.getBalance(SelfDeployedWallet.address);

            const fw1StartBalance = await FooWallet1.runLocal('balance', {});
            const selfDeployWalletStartBalance = await SelfDeployedWallet.runLocal('balance', {});
            logger.log(`FooWallet#1 start balance: ${fw1StartBalance} FOO`);
            logger.log(`FooWallet#4 start balance: ${selfDeployWalletStartBalance} FOO`);

            await FooWallet1.run(
                'transfer',
                {
                    tokens: 1000,
                    to: SelfDeployedWallet.address,
                    grams: freeton.utils.convertCrystal('0.2', 'nano')
                },
                tonWrapper.keys[1]
            ).catch(e => console.log(e));

            // await new Promise((r) => setTimeout(r, 10000));

            const fw1EndBalance = await FooWallet1.runLocal('balance', {});
            const selfDeployWalletEndBalance = await SelfDeployedWallet.runLocal('balance', {});
            logger.log(`FooWallet#1 end balance: ${fw1EndBalance} FOO`);
            logger.log(`FooWallet#4 end balance: ${selfDeployWalletEndBalance} FOO`);

            const fw1EndGrams = await tonWrapper.getBalance(FooWallet1.address);
            const selfDeployWalletEndGrams = await tonWrapper.getBalance(SelfDeployedWallet.address);
            logger.log(`FooWallet#1 GRAMS change:
                ${new BigNumber(fw1EndGrams).minus(fw1StartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`FooWallet#4 GRAMS change:
                ${new BigNumber(selfDeployWalletEndGrams).minus(selfDeployWalletStartGrams).div(1000000000).toFixed(9)} TON`);

            assert.equal(new BigNumber(fw1EndBalance).toNumber(),
                new BigNumber(fw1StartBalance).minus(1000).toNumber(),
                'FooWallet#1 balance wrong');
            assert.equal(new BigNumber(selfDeployWalletEndBalance).toNumber(),
                new BigNumber(selfDeployWalletStartBalance).plus(1000).toNumber(),
                'FooWallet#4 balance wrong');

        });


        it('Transfer by owner (with deploy)', async () => {
            logger.log('######################################################');
            logger.log('BarWallet#6 transfer 1000 to BarWallet#7 (not deployed)');

            bw6address = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[6].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            BarWallet6 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                bw6address
            );

            const bw7address = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[7].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            const bw6StartBalance = await BarWallet6.runLocal('balance', {});
            const bw6StartGrams = await tonWrapper.getBalance(BarWallet6.address);

            logger.log(`BarWallet#6 start balance: ${bw6StartBalance} BAR`);

            await BarWallet6.run(
                'transferByOwner',
                {
                    recipient_public_key: `0x${tonWrapper.keys[7].public}`,
                    recipient_owner_address: ZERO_ADDRESS,
                    tokens: 1000,
                    deploy_grams: freeton.utils.convertCrystal('0.05', 'nano'),
                    transfer_grams: freeton.utils.convertCrystal('0.5', 'nano')
                },
                tonWrapper.keys[6]
            ).catch(e => console.log(e));

            const BarWallet7 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                bw7address
            );

            const bw7EndBalance = await BarWallet7.runLocal('balance', {});
            const bw6EndBalance = await BarWallet6.runLocal('balance', {});

            const bw7EndGrams = await tonWrapper.getBalance(BarWallet7.address);
            const bw6EndGrams = await tonWrapper.getBalance(BarWallet6.address);

            logger.log(`BarWallet#6 GRAMS change:
                ${new BigNumber(bw6EndGrams).minus(bw6StartGrams).div(1000000000).toFixed(9)}`);

            logger.log(`BarWallet#7:
                address = ${bw7Address},
                tokens = ${bw7EndBalance} BAR,
                grams = ${new BigNumber(bw7EndGrams).div(1000000000).toFixed(9)} TON`);

            assert.equal(bw6EndBalance.toNumber(), bw6StartBalance.minus(1000).toNumber(), 'BarWallet#6 balance wrong');
            assert.equal(bw7EndBalance.gte(1000), true, 'BarWallet#7 balance wrong');

        });

        it('onBounce for TONTokenWallet.internalTransfer must increase balance', async () => {
            logger.log('######################################################');
            logger.log('Transfer 100 FOO from FooWallet#2 to non-exists address FooWallet#44 (must be bounced)');

            fw2address = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[2].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            const notExistsWalletAddress = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[44].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            logger.log(`Non-exists address FooWallet#44: ${notExistsWalletAddress}`);

            FooWallet2 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                fw2address
            );

            const startBalance = await FooWallet2.runLocal('balance', {});
            logger.log(`FooWallet#2 start balance: ${startBalance} FOO`);

            logger.log('RUN TONTokenWallet.transfer. That decrease balance.');
            logger.log(`Current FooWallet#2 balance: ${new BigNumber(startBalance).minus(100).toNumber()} FOO`);
            await FooWallet2.run(
                'transfer',
                {
                    tokens: 100,
                    to: notExistsWalletAddress,
                    grams: freeton.utils.convertCrystal('0.3', 'nano')
                },
                tonWrapper.keys[2]
            ).catch(e => console.log(e));

            const endBalance = await FooWallet2.runLocal('balance', {});
            logger.log(`FooWallet#2 end balance: ${endBalance} FOO`);
            assert.equal(new BigNumber(startBalance).toNumber(),
                new BigNumber(endBalance).toNumber(),
                'FooWallet#2 balance wrong');
        });

        it('Transfer wrong tokens', async () => {
            logger.log('######################################################');
            logger.log('Transfer 1000 BAR from BarWallet#3 to FooWallet#1 (must be failed)');

            fw1address = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[1].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            FooWallet1 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                fw1address
            );

            bw3address = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key_: `0x${tonWrapper.keys[3].public}`,
                    owner_address_: ZERO_ADDRESS,
                });

            BarWallet3 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                bw3address
            );

            const fw1StartBalance = await FooWallet1.runLocal('balance', {});
            const bw3startBalance = await BarWallet3.runLocal('balance', {});
            logger.log(`FooWallet#1 start balance: ${fw1StartBalance}`);
            logger.log(`BarWallet#3 start balance: ${bw3startBalance}`);

            const w1StartGrams = await tonWrapper.getBalance(FooWallet1.address);
            const bw3StartGrams = await tonWrapper.getBalance(BarWallet3.address);

            await BarWallet3.run(
                'transfer',
                {
                    tokens: 1000,
                    to: fw1address,
                    grams: freeton.utils.convertCrystal('0.1', 'nano')
                },
                tonWrapper.keys[3]
            ).catch(e => console.log(3));

            const w1EndBalance = await FooWallet1.runLocal('balance', {});
            const bw3EndBalance = await BarWallet3.runLocal('balance', {});
            logger.log(`FooWallet#1 end balance: ${w1EndBalance} BAR`);
            logger.log(`BarWallet#3 end balance: ${bw3EndBalance} BAR`);

            const fw1EndGrams = await tonWrapper.getBalance(FooWallet1.address);
            const bw3EndGrams = await tonWrapper.getBalance(BarWallet3.address);
            logger.log(`FooWallet#1 GRAMS change:
                ${new BigNumber(fw1EndGrams).minus(w1StartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`BarWallet#3 GRAMS change:
                ${new BigNumber(bw3EndGrams).minus(bw3StartGrams).div(1000000000).toFixed(9)} TON`);

            assert.equal(new BigNumber(fw1StartBalance).toNumber(),
                new BigNumber(w1EndBalance).toNumber(),
                'FooWallet#1 balance wrong');
            assert.equal(new BigNumber(bw3startBalance).toNumber(),
                new BigNumber(bw3EndBalance).toNumber(),
                'BarWallet#3 balance wrong');

        });

        it('External call TONTokenWallet.disapprove', async () => {
            logger.log('######################################################');
            logger.log('BarWallet#6 disapprove');
            const allowanceStart = await BarWallet6.runLocal('allowance', {});
            logger.log(`Start allowance:
                remaining_tokens = ${allowanceStart.remaining_tokens},
                spender = ${allowanceStart.spender}`);

            const bw6StartGrams = await tonWrapper.getBalance(BarWallet6.address);

            await BarWallet6.run(
                'disapprove',
                {},
                tonWrapper.keys[6]
            ).catch(e => console.log(e));

            const allowanceEnd = await BarWallet6.runLocal('allowance', {});
            logger.log(`End allowance:
                remaining_tokens = ${allowanceEnd.remaining_tokens},
                spender = ${allowanceEnd.spender}`);

            const bw6EndGrams = await tonWrapper.getBalance(BarWallet6.address);
            logger.log(`BarWallet#6 GRAMS change:
                ${new BigNumber(bw6EndGrams).minus(bw6StartGrams).div(1000000000).toFixed(9)} TON`);

            assert.equal(
                new BigNumber(allowanceEnd.remaining_tokens).toNumber(),
                0,
                'Wrong remaining_tokens');
            assert.equal(allowanceEnd.spender, ZERO_ADDRESS, 'Wrong spender');
        });

        it('External call TONTokenWallet.approve', async () => {
            logger.log('######################################################');
            logger.log('BarWallet#6 approve 10000 to wallet of TONTokenWalletInternalOwnerTest');
            const allowanceStart = await BarWallet6.runLocal('allowance', {});
            logger.log(`Start allowance:
                remaining_tokens = ${allowanceStart.remaining_tokens},
                spender = ${allowanceStart.spender}`);

            const bw6StartGrams = await tonWrapper.getBalance(BarWallet6.address);

            await BarWallet6.run(
                'approve',
                {
                    spender: BarWalletInternal.address,
                    remaining_tokens: allowanceStart.remaining_tokens,
                    tokens: 10000
                },
                tonWrapper.keys[6]
            ).catch(e => console.log(e));

            const allowanceEnd = await BarWallet6.runLocal('allowance', {});
            logger.log(`End allowance:
                remaining_tokens = ${allowanceEnd.remaining_tokens},
                spender = ${allowanceEnd.spender}`);

            const bw6EndGrams = await tonWrapper.getBalance(BarWallet6.address);
            logger.log(`BarWallet#6 GRAMS change:
                ${new BigNumber(bw6EndGrams).minus(bw6StartGrams).div(1000000000).toFixed(9)} TON`);

            assert.equal(
                new BigNumber(allowanceEnd.remaining_tokens).toNumber(),
                new BigNumber(10000).toNumber(),
                'Wrong remaining_tokens');
            assert.equal(allowanceEnd.spender, BarWalletInternal.address, 'Wrong spender');
        });

        it('Internal call TONTokenWallet.transferFrom by TONTokenWalletInternalOwnerTest', async () => {
            logger.log('######################################################');
            logger.log('TONTokenWalletInternalOwnerTest transfer 5000 from BarWallet#6 to BarWallet#3');
            const allowanceStart = await BarWallet6.runLocal('allowance', {});
            const bw3balanceStart = await BarWallet3.runLocal('balance', {});
            const bw6balanceStart = await BarWallet6.runLocal('balance', {});
            logger.log(`Start allowance:
                remaining_tokens = ${allowanceStart.remaining_tokens},
                spender = ${allowanceStart.spender}`);
            logger.log(`Start BarWallet3 balance: ${bw3balanceStart} BAR`);
            logger.log(`Start BarWallet6 balance: ${bw6balanceStart} BAR`);

            const tokensInternalOwnerStartGrams = await tonWrapper.getBalance(TONTokenWalletInternalOwnerTest.address);
            const bw3StartGrams = await tonWrapper.getBalance(BarWallet3.address);
            const bw6StartGrams = await tonWrapper.getBalance(BarWallet6.address);

            await TONTokenWalletInternalOwnerTest.run(
                'testTransferFrom',
                {
                    tokens: 5000,
                    grams: freeton.utils.convertCrystal('3', 'nano'),
                    from: BarWallet6.address,
                    to: BarWallet3.address,
                    wallet: BarWalletInternal.address
                },
                tonWrapper.keys[5]
            ).catch(e => console.log(e));

            const allowanceEnd = await BarWallet6.runLocal('allowance', {});
            const bw3balanceEnd = await BarWallet3.runLocal('balance', {});
            const bw6balanceEnd = await BarWallet6.runLocal('balance', {});
            logger.log(`End allowance:
                remaining_tokens = ${allowanceEnd.remaining_tokens},
                spender = ${allowanceEnd.spender}`);
            logger.log(`End BarWallet3 balance: ${bw3balanceEnd}`);
            logger.log(`End BarWallet6 balance: ${bw6balanceEnd} BAR`);

            const tokensInternalOwnerEndGrams = await tonWrapper.getBalance(TONTokenWalletInternalOwnerTest.address);
            const bw3EndGrams = await tonWrapper.getBalance(BarWallet3.address);
            const bw6EndGrams = await tonWrapper.getBalance(BarWallet6.address);

            const totalGas = new BigNumber(bw3StartGrams)
                .plus(bw6StartGrams)
                .plus(tokensInternalOwnerStartGrams)
                .minus(bw3EndGrams)
                .minus(bw6EndGrams)
                .minus(tokensInternalOwnerEndGrams)
                .div(1000000000)
                .toNumber();

            logger.log(`BarWallet3 GRAMS change:
                ${new BigNumber(bw3EndGrams).minus(bw3StartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`BarWallet6 GRAMS change:
                ${new BigNumber(bw6EndGrams).minus(bw6StartGrams).div(1000000000).toFixed(9)} TON`);
            logger.log(`TONTokenWalletInternalOwnerTest GRAMS change:
                ${new BigNumber(tokensInternalOwnerEndGrams).minus(tokensInternalOwnerStartGrams).div(1000000000).toFixed(9)} TON`);

            logger.log(`GAS used: ${totalGas} TON`);

            assert.equal(
                new BigNumber(bw3balanceStart).plus(5000).toNumber(),
                new BigNumber(bw3balanceEnd).toNumber(),
                'BarWallet#3 balance wrong');
            assert.equal(
                new BigNumber(bw6balanceStart).minus(5000).toNumber(),
                new BigNumber(bw6balanceEnd).toNumber(),
                'BarWallet#6 balance wrong');
            assert.equal(
                new BigNumber(allowanceStart.remaining_tokens).minus(5000).toNumber(),
                new BigNumber(allowanceEnd.remaining_tokens).toNumber(),
                'Wrong remaining_tokens');
            assert.equal(allowanceEnd.spender, BarWalletInternal.address, 'Wrong spender');

        });

    });

});
