import { getRandomNonce, toNano, WalletTypes } from 'locklift';

export const ACCOUNTS_N = 4;
export const ACCOUNT_WALLET_AMOUNT = 100;

export default async () => {
  console.log('Starting creating User Accounts...');

  await locklift.deployments.deployAccounts(
    Array.from({ length: ACCOUNTS_N }, (_, i) => ({
      deploymentName: `commonAccount-${i}`,
      accountSettings: {
        type: WalletTypes.EverWallet,
        value: toNano(ACCOUNT_WALLET_AMOUNT),
        nonce: getRandomNonce(),
      },
      signerId: '0',
    })),
  );

  console.log('User Accounts deployed!');

  for (let j = 0; j < ACCOUNTS_N; j++) {
    const account = locklift.deployments.getAccount(
      `commonAccount-${j}`,
    ).account;

    await locklift.provider.sendMessage({
      sender: account.address,
      recipient: account.address,
      amount: toNano(1),
      bounce: false,
    });

    console.log(`${j} account initialized`);
  }
};

export const tag = 'common-accounts';
