import { getRandomNonce, toNano, WalletTypes } from 'locklift';
import { displayTx } from '../scripts/helpers/utils';

export default async () => {
  console.log('0-DEPLOY-FACTORY');
  const signer = await locklift.keystore.getSigner('0');
  const factoryOwner = process.env.LOCAL_GIVER_ADDRESS;

  const manager = (
    await locklift.deployments.deployAccounts([
      {
        deploymentName: 'ManagerAccount',
        accountSettings: {
          type: WalletTypes.EverWallet,
          value: toNano(1000),
          nonce: getRandomNonce(),
        },
        signerId: '0',
      },
    ])
  )[0]?.account;

  if (locklift.tracing) {
    locklift.tracing.setAllowedCodesForAddress(manager.address, {
      compute: [100],
    });
  }
  const TokenRoot = locklift.factory.getContractArtifacts(
    'TokenRootUpgradeable',
  );
  const TokenWallet = locklift.factory.getContractArtifacts(
    'TokenWalletUpgradeable',
  );
  const TokenWalletPlatform = locklift.factory.getContractArtifacts(
    'TokenWalletPlatform',
  );
  const { contract: tokenFactory } = await locklift.factory.deployContract({
    contract: 'TokenFactory',
    constructorParams: {
      _owner: manager.address,
    },
    initParams: {
      randomNonce_: getRandomNonce(),
    },
    publicKey: signer!.publicKey,
    value: toNano(2),
  });

  await locklift.deployments.saveContract({
    contractName: 'TokenFactory',
    deploymentName: `TokenFactory`,
    address: tokenFactory.address,
  });

  console.log(`TokenFactory: ${tokenFactory.address}`);
  await tokenFactory.methods.setRootCode({ _rootCode: TokenRoot.code }).send({
    from: manager.address,
    amount: toNano(2),
  });
  await tokenFactory.methods
    .setWalletCode({ _walletCode: TokenWallet.code })
    .send({
      from: manager.address,
      amount: toNano(2),
    });
  await tokenFactory.methods
    .setWalletPlatformCode({ _walletPlatformCode: TokenWalletPlatform.code })
    .send({
      from: manager.address,
      amount: toNano(2),
    });

  console.log(`_rootCode / _walletCode / _walletPlatformCode - settled`);

  const tx = await tokenFactory.methods
    .transferOwner({
      answerId: 0,
      newOwner: factoryOwner,
    })
    .send({
      from: manager.address,
      amount: toNano(1),
    });

  displayTx(tx);

  console.log(`Don't forget to accept ownership for ${factoryOwner}`);
};

export const tag = 'factory-account';
