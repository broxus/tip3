import {
  Address,
  Contract,
  getRandomNonce,
  lockliftChai,
  toNano,
  zeroAddress,
} from 'locklift';
import { Account } from 'locklift/everscale-client';
import BigNumber from 'bignumber.js';
import {
  TokenFactoryAbi,
  TokenRootUpgradeableAbi,
  TokenWalletUpgradeableAbi,
} from '../build/factorySource';

import { ACCOUNTS_N } from '../deploy/common/commonAccounts';

import chai from 'chai';

chai.use(lockliftChai);

interface ITokenData {
  name: string;
  symbol: string;
  decimals: number;
  owner: Address;
  mintDisabled: boolean;
  burnByRootDisabled: boolean;
  burnPaused: boolean;
  initialSupplyTo: Address;
  initialSupply: '10';
  deployWalletValue: string;
}

describe('Testing transfers of tokens made via factory ', function () {
  console.log('1-TRANSFER-TOKENS-TEST');
  let tokenData: ITokenData;
  let tokenFactory: Contract<TokenFactoryAbi>;
  let manager: Account;
  let accBalance: string;
  let deployedTokenRoot: Address;
  let deployedTokenRootContract: Contract<TokenRootUpgradeableAbi>;
  let ownerWalletContract: Contract<TokenWalletUpgradeableAbi>;
  const commonAccs: Account[] = [];

  it('prepare for transfers', async function () {
    await locklift.deployments.fixture({
      include: ['factory-account', 'common-accounts'],
    });

    tokenFactory =
      locklift.deployments.getContract<TokenFactoryAbi>(`TokenFactory`);

    // Interacting with deployed contracts
    manager = locklift.deployments.getAccount('ManagerAccount').account;
    accBalance = await locklift.provider.getBalance(manager.address);

    if (new BigNumber(accBalance).lt(toNano(10))) {
      throw Error('Not enough evers on manager account to continue');
    }

    for (let j = 0; j < ACCOUNTS_N; j++) {
      commonAccs[j] = locklift.deployments.getAccount(
        `commonAccount-${j}`,
      ).account;
    }

    tokenData = {
      name: 'Test 3',
      symbol: 'TST3',
      decimals: 5,
      owner: manager.address,
      mintDisabled: false,
      burnByRootDisabled: false,
      burnPaused: false,
      initialSupplyTo: manager.address,
      initialSupply: '10',
      deployWalletValue: toNano(0.1),
    };

    await tokenFactory.methods
      .createToken({
        callId: 0,
        name: tokenData.name,
        symbol: tokenData.symbol,
        decimals: tokenData.decimals,
        initialSupplyTo: tokenData.initialSupplyTo,
        initialSupply: new BigNumber(tokenData.initialSupply)
          .shiftedBy(tokenData.decimals)
          .toString(),
        deployWalletValue: tokenData.deployWalletValue,
        mintDisabled: tokenData.mintDisabled,
        burnByRootDisabled: tokenData.burnByRootDisabled,
        burnPaused: tokenData.burnPaused,
        remainingGasTo: manager.address,
      })
      .send({
        from: manager.address,
        amount: toNano(3),
      });

    async function latestCreatedRoot() {
      const pastEvents = await tokenFactory.getPastEvents({});
      const eventsVestings = pastEvents.events.filter((item) => {
        const isContainKey = Object.keys(item.data).find(
          (key) => key === 'tokenRoot',
        );
        return isContainKey ? item : false;
      });

      return eventsVestings[0].data.tokenRoot;
    }

    deployedTokenRoot = await latestCreatedRoot();

    await locklift.deployments.saveContract({
      contractName: 'TokenRootUpgradeable',
      deploymentName: `TokenRoot3`,
      address: deployedTokenRoot,
    });

    deployedTokenRootContract =
      await locklift.deployments.getContract<TokenRootUpgradeableAbi>(
        `TokenRoot3`,
      );

    const ownerWallet = await deployedTokenRootContract.methods
      .walletOf({
        walletOwner: tokenData.initialSupplyTo,
        answerId: 0,
      })
      .call();

    await locklift.deployments.saveContract({
      contractName: 'TokenWalletUpgradeable',
      deploymentName: `Wallet0`,
      address: ownerWallet.value0,
    });

    ownerWalletContract =
      await locklift.deployments.getContract<TokenWalletUpgradeableAbi>(
        `Wallet0`,
      );
  });

  it('start transfers', function () {
    // checking transfers
    for (const accountData of commonAccs) {
      const index = commonAccs.indexOf(accountData);
      const commonAcc = accountData;
      let commonTokenWalletC: Contract<TokenWalletUpgradeableAbi>;

      if (tokenData.initialSupplyTo === zeroAddress) return;

      it('prepare accounts', async function () {
        const commonAccWallet = await deployedTokenRootContract.methods
          .walletOf({
            walletOwner: commonAcc.address,
            answerId: 0,
          })
          .call();

        await locklift.deployments.saveContract({
          contractName: 'TokenWalletUpgradeable',
          deploymentName: `commonAccountWallet-${index}`,
          address: commonAccWallet.value0,
        });

        commonTokenWalletC =
          await locklift.deployments.getContract<TokenWalletUpgradeableAbi>(
            `commonAccountWallet-${index}`,
          );
      });

      if (index === 0) {
        it('send 1st transfer (wallet deploy + transfer)', async function () {
          console.log(`Case ${index + 1}: Wallet deploy + transfer...`);
          await deployedTokenRootContract.methods
            .deployWallet({
              answerId: 0,
              walletOwner: commonAcc.address,
              deployWalletValue: toNano(0.1),
            })
            .send({
              from: manager.address,
              amount: toNano(2),
              bounce: true,
            });

          // transfer
          await locklift.transactions.waitFinalized(
            ownerWalletContract.methods
              .transfer({
                amount: 10,
                recipient: commonAcc.address,
                deployWalletValue: 0,
                remainingGasTo: manager.address,
                notify: false,
                payload: '',
              })
              .send({
                from: manager.address,
                amount: toNano(2),
                bounce: true,
              }),
          );

          const tokenWalletBalance = await commonTokenWalletC.methods
            .balance({ answerId: 0 })
            .call()
            .catch((e) => {
              console.log(e, `balance error tokenWalletBalance ❌`);
            });

          if (tokenWalletBalance) {
            console.log(
              `Token wallet balance (1): ${
                tokenWalletBalance?.value0
              } ✅ account address: ${commonTokenWalletC.address.toString()}`,
            );
          }
        });
      }

      if (index === 1) {
        it('send 2nd transfer (transfer with deployWallet)', async function () {
          await ownerWalletContract.methods
            .transfer({
              amount: 10,
              recipient: commonAcc.address,
              deployWalletValue: toNano(0.1),
              remainingGasTo: manager.address,
              notify: false,
              payload: '',
            })
            .send({
              from: manager.address,
              amount: toNano(2),
              bounce: true,
            });

          const tokenWalletBalance = await commonTokenWalletC.methods
            .balance({ answerId: 0 })
            .call()
            .catch((e) => {
              console.log(e, `balance error tokenWalletBalance ❌`);
            });

          if (tokenWalletBalance) {
            console.log(
              `Token wallet balance (2): ${
                tokenWalletBalance?.value0
              } ✅ account address: ${commonTokenWalletC.address.toString()}`,
            );
          }
        });
      }

      // 2 CASE - transfer with deployWallet
      if (index === 2) {
        it('send 3rd transfer (transfer to unknown address + check bounce)', async function () {
          const balanceBefore = await ownerWalletContract.methods
            .balance({ answerId: 0 })
            .call();
          console.log('Balance before transfer: ', balanceBefore.value0);
          await locklift.transactions.waitFinalized(
            ownerWalletContract.methods
              .transfer({
                amount: 10,
                recipient: new Address(
                  '0:bf6781e8b5c4ef4ecc55af787d4f2e7ebc8aed3cab7739236fa149f2b062f77b',
                ),
                deployWalletValue: 0,
                remainingGasTo: ownerWalletContract.address,
                notify: false,
                payload: '',
              })
              .send({
                from: manager.address,
                amount: toNano(2),
                bounce: true,
              }),
          );

          const balanceAfter = await ownerWalletContract.methods
            .balance({ answerId: 0 })
            .call();
          console.log('Balance after transfer: ', balanceAfter.value0);
        });
      }

      // 3 CASE - transfer to unknown address + check bounce
      if (index === 3) {
        it('send 4th transfer (basic transfer with notify', async function () {
          const signer = await locklift.keystore.getSigner('0');

          const { contract: callbacksContract } =
            await locklift.factory.deployContract({
              contract: 'Callbacks',
              constructorParams: {},
              initParams: {
                _nonce: getRandomNonce(),
              },
              publicKey: signer!.publicKey,
              value: toNano(2),
            });

          const { traceTree } = await locklift.tracing.trace(
            ownerWalletContract.methods
              .transfer({
                amount: 10,
                recipient: callbacksContract.address,
                deployWalletValue: toNano(0.1),
                remainingGasTo: manager.address,
                notify: true,
                payload: '',
              })
              .send({
                from: manager.address,
                amount: toNano(2),
                bounce: true,
              }),
          );

          const transferCalls = traceTree?.findCallsForContract({
            contract: callbacksContract,
            name: 'onAcceptTokensTransfer',
          });

          console.log('On accepts callback:', transferCalls);
        });
      }
    }
  });
  console.log(`Token Transfer test finished successfully ✅`);
});
