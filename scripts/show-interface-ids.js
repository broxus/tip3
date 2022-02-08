const logger = require('mocha-logger');

async function main() {
    const keyPairs = await locklift.keys.getKeyPairs();

    const selectors = [
        'AcceptTransfer',
        'AcceptMint',
        'AcceptBurn',
    ];

    const interfaces = [
        'TIP3TokenRoot',
        'TIP3TokenWallet',
        'SID',
        'TokenRoot',
        'TokenWallet',
        'TransferableOwnership',
        'BurnableTokenWallet',
        'BurnableByRootTokenRoot',
        'BurnableByRootTokenWallet',
        'Destroyable',
        'Versioned',
        'DisableableMintTokenRoot',
        'BurnPausableTokenRoot',
        'TokenWalletUpgradeable',
        'TokenRootUpgradeable',
    ];

    const Selector = await locklift.factory.getContract('Selector');

    let selector = await locklift.giver.deployContract({
        contract: Selector,
        constructorParams: {},
        initParams: {
            _randomNonce: Math.random() * 6400 | 0,
        },
        keyPair: keyPairs[0],
    }, locklift.utils.convertCrystal('1', 'nano'));

    for(let i in selectors) {
        const result = await Selector.call({
            method: `calculate${selectors[i]}Selector`,
            params: {}
        });
        logger.log(`${selectors[i]}: 0x${result.toString(16)}`);
    }

    for(let i in interfaces) {
        const result = await Selector.call({
            method: `calculate${interfaces[i]}InterfaceID`,
            params: {}
        });
        logger.log(`${interfaces[i]}: 0x${result.toString(16)}`);
    }

}

main()
    .then(() => process.exit(0))
    .catch(e => {
        console.log(e);
        process.exit(1);
    });
