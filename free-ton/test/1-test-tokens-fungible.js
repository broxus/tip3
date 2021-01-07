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
let BurnTokensCallbackExample;
let wallet1address;
let Wallet1;
let wallet2address;
let Wallet2;
let barWalletInternalAddress;
let BarWalletInternal;
let barWallet3address;
let BarWallet3;
let barWallet6address;
let BarWallet6;


const tonWrapper = new freeton.TonWrapper({
    network: process.env.NETWORK,
    seed: process.env.SEED,
    randomTruffleNonce: Boolean(process.env.RANDOM_TRUFFLE_NONCE),
});


describe('Test Fungible Tokens', function () {
    this.timeout(100000);

    before(async function () {
        await tonWrapper.setup();

        RootTokenContractExternalOwner = await freeton.requireContract(tonWrapper, 'RootTokenContract', null, 'RootTokenContractExternalOwner');
        RootTokenContractInternalOwner = await freeton.requireContract(tonWrapper, 'RootTokenContract', null, 'RootTokenContractInternalOwner');
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
        logger.log(`SelfDeployedWallet (wallet#4) address: ${SelfDeployedWallet.address}`);
        logger.log(`TONTokenWalletHack address: ${TONTokenWalletHack.address}`);
        logger.log(`DeployEmptyWalletFor address: ${DeployEmptyWalletFor.address}`);
    });

    describe('Test deploy wallets', async function () {
        it('Deploy empty wallet for #0 user using DeployEmptyWalletFor contract', async () => {

            const expectedAddress = await RootTokenContractExternalOwner.runLocal('getWalletAddress', {
                wallet_public_key: `0x${tonWrapper.keys[0].public}`,
                owner_address: ZERO_ADDRESS,
            });
            logger.log(`expectedAddress = ${expectedAddress}`);

            const root = await DeployEmptyWalletFor.runLocal('getRoot', {});
            logger.log(`root = ${root}`);

            const keyStart = await DeployEmptyWalletFor.runLocal('getLatestPublicKey', {});
            logger.log(`keyStart = ${keyStart}`);

            const addrStart = await DeployEmptyWalletFor.runLocal('getLatestAddr', {});
            logger.log(`addrStart = ${addrStart}`);

            await DeployEmptyWalletFor.run('deployEmptyWalletFor', {
                pubkey: `0x${tonWrapper.keys[0].public}`,
                addr: ZERO_ADDRESS
            }, tonWrapper.keys[0]);

            await new Promise((r) => setTimeout(r, 10000));

            const keyEnd = await DeployEmptyWalletFor.runLocal('getLatestPublicKey', {});
            logger.log(`keyEnd = ${keyEnd}`);

            const addrEnd = await DeployEmptyWalletFor.runLocal('getLatestAddr', {});
            logger.log(`addrEnd = ${addrEnd}`);

            const DeployedWallet = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                expectedAddress
            );

            const balance = await DeployedWallet.runLocal('getBalance', {});
            logger.log(`wallet#0 ${expectedAddress} balance = ${balance}`);
            assert.ok(1);
        });

        it('Deploy wallet for #1 user with 10.000 tokens', async () => {
            await RootTokenContractExternalOwner.run(
                'deployWallet',
                {
                    tokens: 10000,
                    grams: freeton.utils.convertCrystal('1', 'nano'),
                    wallet_public_key: `0x${tonWrapper.keys[1].public}`,
                    owner_address: ZERO_ADDRESS,
                },
                tonWrapper.keys[0]
            );

            wallet1address = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[1].public}`,
                    owner_address: ZERO_ADDRESS,
                });

            Wallet1 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                wallet1address
            );

            const balance = await Wallet1.runLocal('getBalance', {});
            logger.log(`wallet1address: ${wallet1address}, balance = ${balance}`);
            assert.ok(wallet1address);
        });

        it('Deploy wallet for #2 user with 20.000 tokens', async () => {
            await RootTokenContractExternalOwner.run(
                'deployWallet',
                {
                    tokens: 20000,
                    grams: freeton.utils.convertCrystal('1', 'nano'),
                    wallet_public_key: `0x${tonWrapper.keys[2].public}`,
                    owner_address: ZERO_ADDRESS,
                },
                tonWrapper.keys[0]
            );

            wallet2address = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[2].public}`,
                    owner_address: ZERO_ADDRESS,
                });

            Wallet2 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                wallet2address
            );

            const balance = await Wallet2.runLocal('getBalance', {});

            logger.log(`wallet2address: ${wallet2address}, balance = ${balance}`);
            assert.ok(wallet2address);
        });

        it('Deploy BarToken wallet for TONTokenWalletInternalOwnerTest', async () => {
            await TONTokenWalletInternalOwnerTest.run(
                'deployEmptyWallet',
                {
                    root_address: RootTokenContractInternalOwner.address,
                    grams: freeton.utils.convertCrystal('5', 'nano')
                },
                tonWrapper.keys[5]
            );

            barWalletInternalAddress = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x0`,
                    owner_address: TONTokenWalletInternalOwnerTest.address,
                });

            BarWalletInternal = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                barWalletInternalAddress
            );
            const balance = await BarWalletInternal.runLocal('getBalance', {});

            logger.log(`fakeWallet3address: ${barWalletInternalAddress}, balance = ${balance}`);
            assert.ok(barWalletInternalAddress);
        });

        it('Deploy BarToken wallet for user #3 with 30000 BAR', async () => {
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

            barWallet3address = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[3].public}`,
                    owner_address: ZERO_ADDRESS,
                });

            BarWallet3 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                barWallet3address
            );
            const balance = await BarWallet3.runLocal('getBalance', {});

            logger.log(`barWallet3address: ${barWallet3address}, balance = ${balance}`);
            assert.ok(barWallet3address);
        });

        it('Deploy BarToken wallet for user #6 with 60000 BAR', async () => {
            await RootTokenContractInternalOwnerTest.run(
                'deployWallet',
                {
                    tokens: 60000,
                    grams: freeton.utils.convertCrystal('2.5', 'nano'),
                    pubkey: `0x${tonWrapper.keys[6].public}`,
                    addr: ZERO_ADDRESS,
                },
                tonWrapper.keys[0]
            ).catch(e => console.log(e));

            barWallet6address = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[6].public}`,
                    owner_address: ZERO_ADDRESS,
                });

            BarWallet6 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                barWallet6address
            );
            const balance = await BarWallet6.runLocal('getBalance', {});

            logger.log(`barWallet6address: ${barWallet6address}, balance = ${balance}`);
            assert.ok(barWallet6address);
        });

        it('Check self deployed wallet address', async () => {

            const expectedAddress = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[4].public}`,
                    owner_address: ZERO_ADDRESS,
                });

            logger.log(`Expected address for user #4: ${expectedAddress}`);
            logger.log(`User self deploy wallet address: ${SelfDeployedWallet.address}`);
            assert.equal(expectedAddress, SelfDeployedWallet.address, 'Wallets address not equals');
        });

        it('Check hacker address', async () => {
            const expectedAddress = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[9].public}`,
                    owner_address: ZERO_ADDRESS,
                });

            logger.log(`Expected address for user #9: ${expectedAddress}`);
            logger.log(`Hacker wallet address: ${TONTokenWalletHack.address}`);
            assert.notEqual(expectedAddress, TONTokenWalletHack.address, 'Wallets address equals');
        });
    });

    describe('Test mint/burn', async function () {
        it('Mint 100.000 tokens for barWalletInternal', async () => {
            const startBalance = await BarWalletInternal.runLocal('getBalance', {});
            const startTotalSupply = await RootTokenContractInternalOwner.runLocal('getTotalSupply', {});
            logger.log(`Start balance of barWalletInternal: ${startBalance}`);
            logger.log(`Start total supply: ${startTotalSupply}`);

            await RootTokenContractInternalOwnerTest.run(
                'mint',
                {
                    tokens: 100000,
                    addr: barWalletInternalAddress
                },
                tonWrapper.keys[0]
            ).catch(e => console.log(e));

            const endBalance = await BarWalletInternal.runLocal('getBalance', {});
            const endTotalSupply = await RootTokenContractInternalOwner.runLocal('getTotalSupply', {});
            logger.log(`End balance of barWalletInternal: ${endBalance}`);
            logger.log(`End total supply: ${endTotalSupply}`);

            assert.equal(
                new BigNumber(startBalance).plus(100000).toNumber(),
                new BigNumber(endBalance).toNumber(),
                'Balance wrong');
            assert.equal(
                new BigNumber(startTotalSupply).plus(100000).toNumber(),
                new BigNumber(endTotalSupply).toNumber(),
                'Total supply wrong');
        });

        it('BurnByOwner 5.000 tokens from barWallet#3', async () => {
            const startBalance = await BarWallet3.runLocal('getBalance', {});
            const startTotalSupply = await RootTokenContractInternalOwner.runLocal('getTotalSupply', {});
            const startBurnedCount = await RootTokenContractInternalOwnerTest.runLocal('getBurnedCount', {});
            const startLatestPayload = await RootTokenContractInternalOwnerTest.runLocal('getLatestPayload', {});

            logger.log(`Start balance of barWallet#3: ${startBalance}`);
            logger.log(`Start total supply: ${startTotalSupply}`);
            logger.log(`Start burned count: ${startBurnedCount}`);
            logger.log(`Start payload: ${startLatestPayload}`);

            barWallet3address = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[3].public}`,
                    owner_address: ZERO_ADDRESS,
                });

            BarWallet3 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                barWallet3address
            );

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

            const endBalance = await BarWallet3.runLocal('getBalance', {});
            const endTotalSupply = await RootTokenContractInternalOwner.runLocal('getTotalSupply', {});
            const endBurnedCount = await RootTokenContractInternalOwnerTest.runLocal('getBurnedCount', {});
            const endLatestPayload = await RootTokenContractInternalOwnerTest.runLocal('getLatestPayload', {});
            logger.log(`End balance of barWallet#3: ${endBalance}`);
            logger.log(`End total supply: ${endTotalSupply}`);
            logger.log(`End burned count: ${endBurnedCount}`);
            logger.log(`End payload: ${endLatestPayload}`);

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

        it('BurnByRoot 50.000 tokens from barWalletInternal', async () => {
            const startBalance = await BarWalletInternal.runLocal('getBalance', {});
            const startTotalSupply = await RootTokenContractInternalOwner.runLocal('getTotalSupply', {});
            const startBurnedCount = await RootTokenContractInternalOwnerTest.runLocal('getBurnedCount', {});
            const startLatestPayload = await RootTokenContractInternalOwnerTest.runLocal('getLatestPayload', {});

            logger.log(`Start balance of barWalletInternal: ${startBalance}`);
            logger.log(`Start total supply: ${startTotalSupply}`);
            logger.log(`Start burned count: ${startBurnedCount}`);
            logger.log(`Start payload: ${startLatestPayload}`);

            await TONTokenWalletInternalOwnerTest.run(
                'burnMyTokens',
                {
                    tokens: 50000,
                    grams: freeton.utils.convertCrystal('3', 'nano'),
                    burner_address: RootTokenContractInternalOwnerTest.address,
                    callback_address: RootTokenContractInternalOwnerTest.address,
                    callback_payload: startLatestPayload
                },
                tonWrapper.keys[5]
            ).catch(e => console.log(e));

            const endBalance = await BarWalletInternal.runLocal('getBalance', {});
            const endTotalSupply = await RootTokenContractInternalOwner.runLocal('getTotalSupply', {});
            const endBurnedCount = await RootTokenContractInternalOwnerTest.runLocal('getBurnedCount', {});
            const endLatestPayload = await RootTokenContractInternalOwnerTest.runLocal('getLatestPayload', {});
            logger.log(`End balance of barWalletInternal: ${endBalance}`);
            logger.log(`End total supply: ${endTotalSupply}`);
            logger.log(`End burned count: ${endBurnedCount}`);
            logger.log(`End payload: ${endLatestPayload}`);

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

        it('Mint 10.000 tokens for non exists address', async () => {
            const startTotalSupply = await RootTokenContractExternalOwner.runLocal('getTotalSupply', {});
            logger.log(`Start total supply: ${startTotalSupply}`);
            const notExistsWalletAddress = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[44].public}`,
                    owner_address: ZERO_ADDRESS,
                });
            await RootTokenContractExternalOwner.run(
                'mint',
                {
                    to: notExistsWalletAddress,
                    tokens: 10000
                },
                tonWrapper.keys[0]
            );

            const endTotalSupply = await RootTokenContractExternalOwner.runLocal('getTotalSupply', {});
            logger.log(`End total supply: ${endTotalSupply}`);

            assert.equal(
                new BigNumber(startTotalSupply).toNumber(),
                new BigNumber(endTotalSupply).toNumber(),
                'Total supply wrong');
        });
    });

    describe('Trying to hack', async function () {
        it('Fake internal_transfer(...) call from hacker address', async () => {
            const startBalance = await SelfDeployedWallet.runLocal('getBalance', {});
            logger.log(`Start balance for ${SelfDeployedWallet.address}: ${startBalance}`);

            await TONTokenWalletHack.run(
                'mint',
                {
                    tokens: 1000,
                    to: SelfDeployedWallet.address,
                    grams: freeton.utils.convertCrystal('0.2', 'nano')
                },
                tonWrapper.keys[9]
            );

            const endBalance = await SelfDeployedWallet.runLocal('getBalance', {});
            logger.log(`End balance for ${SelfDeployedWallet.address}: ${endBalance}`);
            assert.equal(new BigNumber(startBalance).toNumber(), new BigNumber(endBalance).toNumber(), 'Exploit expected');
        });
    });

    describe('Test transfer', async function () {

        it('Transfer 1000 tokens from wallet#2 to wallet#1', async () => {
            wallet1address = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[1].public}`,
                    owner_address: ZERO_ADDRESS,
                });

            Wallet1 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                wallet1address
            );

            wallet2address = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[2].public}`,
                    owner_address: ZERO_ADDRESS,
                });

            Wallet2 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                wallet2address
            );

            const w1StartBalance = await Wallet1.runLocal('getBalance', {});
            const w2StartBalance = await Wallet2.runLocal('getBalance', {});
            logger.log(`wallet#1 ${wallet1address} start balance: ${w1StartBalance}`);
            logger.log(`wallet#2 ${wallet2address} start balance: ${w2StartBalance}`);

            await Wallet2.run(
                'transfer',
                {
                    tokens: 1000,
                    to: wallet1address,
                    grams: freeton.utils.convertCrystal('0.1', 'nano')
                },
                tonWrapper.keys[2]
            );

            await new Promise((r) => setTimeout(r, 10000));

            const w1EndBalance = await Wallet1.runLocal('getBalance', {});
            const w2EndBalance = await Wallet2.runLocal('getBalance', {});
            logger.log(`wallet#1 end balance: ${w1EndBalance}`);
            logger.log(`wallet#2 end balance: ${w2EndBalance}`);
            assert.equal(new BigNumber(w1EndBalance).toNumber(), new BigNumber(w1StartBalance).plus(1000).toNumber(), 'Wallet 1 balance wrong');
            assert.equal(new BigNumber(w2EndBalance).toNumber(), new BigNumber(w2StartBalance).minus(1000).toNumber(), 'Wallet 2 balance wrong');

        });

        it('Transfer 1000 tokens from wallet#1 to self deployed wallet#0', async () => {
            wallet1address = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[1].public}`,
                    owner_address: ZERO_ADDRESS,
                });

            Wallet1 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                wallet1address
            );

            const w1StartBalance = await Wallet1.runLocal('getBalance', {});
            const selfDeployWalletStartBalance = await SelfDeployedWallet.runLocal('getBalance', {});
            logger.log(`wallet#1 ${wallet1address} start balance: ${w1StartBalance}`);
            logger.log(`self deploy wallet ${SelfDeployedWallet.address} start balance: ${selfDeployWalletStartBalance}`);

            await Wallet1.run(
                'transfer',
                {
                    tokens: 1000,
                    to: SelfDeployedWallet.address,
                    grams: freeton.utils.convertCrystal('0.2', 'nano')
                },
                tonWrapper.keys[1]
            );

            await new Promise((r) => setTimeout(r, 10000));

            const w1EndBalance = await Wallet1.runLocal('getBalance', {});
            const selfDeployWalletEndBalance = await SelfDeployedWallet.runLocal('getBalance', {});
            logger.log(`wallet#1 end balance: ${w1EndBalance}`);
            logger.log(`self deploy wallet end balance: ${selfDeployWalletEndBalance}`);
            assert.equal(new BigNumber(w1EndBalance).toNumber(), new BigNumber(w1StartBalance).minus(1000).toNumber(), 'Wallet 1 balance wrong');
            assert.equal(new BigNumber(selfDeployWalletEndBalance).toNumber(), new BigNumber(selfDeployWalletStartBalance).plus(1000).toNumber(), 'Self deploy wallet balance wrong');

        });

        it('Transfer 100 tokens from wallet#2 to non-exists address (must be bounced)', async () => {

            wallet2address = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[2].public}`,
                    owner_address: ZERO_ADDRESS,
                });

            const notExistsWalletAddress = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[44].public}`,
                    owner_address: ZERO_ADDRESS,
                });

            Wallet2 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                wallet2address
            );

            const startBalance = await Wallet2.runLocal('getBalance', {});
            logger.log(`wallet#2 ${wallet2address} start balance: ${startBalance}`);

            await Wallet2.run(
                'transfer',
                {
                    tokens: 100,
                    to: notExistsWalletAddress,
                    grams: freeton.utils.convertCrystal('0.1', 'nano')
                },
                tonWrapper.keys[2]
            );
            logger.log(`notExistsWalletAddress: ${notExistsWalletAddress}`);

            await new Promise((r) => setTimeout(r, 20000));

            const endBalance = await Wallet2.runLocal('getBalance', {});
            logger.log(`wallet#2 ${wallet2address} end balance: ${endBalance}`);
            assert.equal(new BigNumber(startBalance).toNumber(), new BigNumber(endBalance).toNumber(), 'Wallet2 balance wrong');
        });

        it('Transfer 5000 tokens from barWallet#3 to wallet#1 (must be failed)', async () => {

            wallet1address = await RootTokenContractExternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[1].public}`,
                    owner_address: ZERO_ADDRESS,
                });

            Wallet1 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                wallet1address
            );

            barWallet3address = await RootTokenContractInternalOwner.runLocal(
                'getWalletAddress',
                {
                    wallet_public_key: `0x${tonWrapper.keys[3].public}`,
                    owner_address: ZERO_ADDRESS,
                });

            BarWallet3 = await freeton.requireContract(
                tonWrapper,
                'TONTokenWallet',
                barWallet3address
            );

            const w1StartBalance = await Wallet1.runLocal('getBalance', {});
            const bw3startBalance = await BarWallet3.runLocal('getBalance', {});
            logger.log(`wallet#1 ${wallet1address} start balance: ${w1StartBalance}`);
            logger.log(`barwallet#3 ${barWallet3address} start balance: ${bw3startBalance}`);

            await BarWallet3.run(
                'transfer',
                {
                    tokens: 1000,
                    to: wallet1address,
                    grams: freeton.utils.convertCrystal('0.1', 'nano')
                },
                tonWrapper.keys[3]
            ).catch(e => console.log(3));

            await new Promise((r) => setTimeout(r, 10000));

            const w1EndBalance = await Wallet1.runLocal('getBalance', {});
            const bw3EndBalance = await BarWallet3.runLocal('getBalance', {});
            logger.log(`wallet#1 end balance: ${w1EndBalance}`);
            logger.log(`barwallet#3 end balance: ${bw3EndBalance}`);
            assert.equal(new BigNumber(w1StartBalance).toNumber(), new BigNumber(w1EndBalance).toNumber(), 'Wallet1 balance wrong');
            assert.equal(new BigNumber(bw3startBalance).toNumber(), new BigNumber(bw3EndBalance).toNumber(), 'BarWallet3 balance wrong');

        });

        it('barWallet#6 disapprove', async () => {
            const allowanceStart = await BarWallet6.runLocal('allowance', {});
            logger.log(`Start allowance: remaining_tokens = ${allowanceStart.remaining_tokens}, spender = ${allowanceStart.spender}, `);

            await BarWallet6.run(
                'disapprove',
                {},
                tonWrapper.keys[6]
            ).catch(e => console.log(e));

            const allowanceEnd = await BarWallet6.runLocal('allowance', {});
            logger.log(`End allowance: remaining_tokens = ${allowanceEnd.remaining_tokens}, spender = ${allowanceEnd.spender}, `);
            assert.ok(allowanceEnd);
        });

        it('barWallet#6 approve 10000 to wallet of TONTokenWalletInternalOwnerTest', async () => {
            const allowanceStart = await BarWallet6.runLocal('allowance', {});
            logger.log(`Start allowance: remaining_tokens = ${allowanceStart.remaining_tokens}, spender = ${allowanceStart.spender}, `);

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
            logger.log(`End allowance: remaining_tokens = ${allowanceEnd.remaining_tokens}, spender = ${allowanceEnd.spender}, `);
            assert.equal(
                new BigNumber(allowanceEnd.remaining_tokens).toNumber(),
                new BigNumber(10000).toNumber(),
                'Allowance wrong');
        });

        it('TONTokenWalletInternalOwnerTest transfer 5000 from barWallet#6 to barWallet#3', async () => {
            const allowanceStart = await BarWallet6.runLocal('allowance', {});
            const w3balanceStart = await BarWallet3.runLocal('getBalance', {});
            const w6balanceStart = await BarWallet6.runLocal('getBalance', {});
            logger.log(`Start allowance: remaining_tokens = ${allowanceStart.remaining_tokens}, spender = ${allowanceStart.spender}, `);
            logger.log(`Start barWallet3 balance = ${w3balanceStart}`);
            logger.log(`Start barWallet6 balance = ${w6balanceStart}`);

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
            const w3balanceEnd = await BarWallet3.runLocal('getBalance', {});
            const w6balanceEnd = await BarWallet6.runLocal('getBalance', {});
            logger.log(`End allowance: remaining_tokens = ${allowanceEnd.remaining_tokens}, spender = ${allowanceEnd.spender}, `);
            logger.log(`End barWallet3 balance = ${w3balanceEnd}`);
            logger.log(`End barWallet6 balance = ${w6balanceEnd}`);
            assert.equal(
                new BigNumber(w3balanceStart).plus(5000).toNumber(),
                new BigNumber(w3balanceEnd).toNumber(),
                'BarWallet#3 balance wrong');
            assert.equal(
                new BigNumber(w6balanceStart).minus(5000).toNumber(),
                new BigNumber(w6balanceEnd).toNumber(),
                'BarWallet#6 balance wrong');
            assert.equal(
                new BigNumber(allowanceStart.remaining_tokens).minus(5000).toNumber(),
                new BigNumber(allowanceEnd.remaining_tokens).toNumber(),
                'Allowance wrong');

        });

    });

});
