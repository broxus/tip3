import { SelectorAbi } from 'build/factorySource';

async function main() {
  const selectors = ['AcceptTransfer', 'AcceptMint', 'AcceptBurn'];

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

  const Selector = locklift.deployments.getContract<SelectorAbi>('Selector');

  for (const i in selectors) {
    const key = `calculate${selectors[i]}Selector`;
    const result = await (Selector.methods as any)[key].call();
    console.log(`${selectors[i]}: 0x${result.toString(16)}`);
  }

  for (const i in interfaces) {
    const key = `calculate${interfaces[i]}InterfaceID`;
    const result = await (Selector.methods as any)[key].call();
    console.log(`${interfaces[i]}: 0x${result.toString(16)}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.log(e);
    process.exit(1);
  });
