import { getRandomNonce, toNano, WalletTypes } from 'locklift';
import prompts, { PromptObject } from 'prompts';

import { Command } from 'commander';
import { displayTx, isValidEverAddress } from './helpers/utils';

const program = new Command();

async function main() {
  console.log('1-DEPLOY-FACTORY');
  const signer = await locklift.keystore.getSigner('0');

  const promptsData: PromptObject[] = [];

  program
    .allowUnknownOption()
    .option('-fo, --factory_owner <root_owner>', 'Token factory owner');

  program.parse(process.argv);

  const options = program.opts();

  if (!isValidEverAddress(options.root_owner)) {
    promptsData.push({
      type: 'text',
      name: 'factoryOwner',
      message: 'Factory owner',
      validate: (value) =>
        isValidEverAddress(value) ? true : 'Invalid Ever address',
    });
  }

  const response = await prompts(promptsData);
  const factoryOwner = options.factory_owner || response.factoryOwner;

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
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.log(e);
    process.exit(1);
  });
