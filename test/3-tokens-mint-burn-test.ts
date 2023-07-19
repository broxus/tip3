import { Contract, getRandomNonce, lockliftChai, toNano } from 'locklift';
import BigNumber from 'bignumber.js';
import {
  CallbacksAbi,
  TokenFactoryAbi,
  TokenRootUpgradeableAbi,
} from '../build/factorySource';

import chai from 'chai';
import { Account } from 'locklift/everscale-client';

chai.use(lockliftChai);

describe('Testing tokens mint and burn methods', function () {
  console.log('2-TOKENS-MINT-BURN-TEST');
  let tokenFactory: Contract<TokenFactoryAbi>;
  let manager: Account;
  let accBalance: string;
  let deployedTokenRootContract: Contract<TokenRootUpgradeableAbi>;
  let callbacksContractVar: Contract<CallbacksAbi>;

  it('prepare for mint and burn', async function () {
    await locklift.deployments.load();

    tokenFactory =
      locklift.deployments.getContract<TokenFactoryAbi>(`TokenFactory`);

    // Interacting with deployed contracts
    manager = locklift.deployments.getAccount('ManagerAccount').account;
    accBalance = await locklift.provider.getBalance(manager.address);
    if (new BigNumber(accBalance).lt(toNano(10))) {
      throw Error('Not enough evers on manager account to continue');
    }

    const tokenData = {
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

    const deployedTokenRoot = await latestCreatedRoot();
    await locklift.deployments.saveContract({
      contractName: 'TokenRootUpgradeable',
      deploymentName: `TokenRoot4`,
      address: deployedTokenRoot,
    });

    deployedTokenRootContract =
      await locklift.deployments.getContract<TokenRootUpgradeableAbi>(
        `TokenRoot4`,
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

    const commonAcc = await locklift.deployments.getAccount(`commonAccount-0`)
      .account;

    const commonAccWallet = await deployedTokenRootContract.methods
      .walletOf({
        walletOwner: commonAcc.address,
        answerId: 0,
      })
      .call();

    await locklift.deployments.saveContract({
      contractName: 'TokenWalletUpgradeable',
      deploymentName: `commonAccountWallet-0`,
      address: commonAccWallet.value0,
    });

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

    callbacksContractVar = callbacksContract;
  });

  describe('starting mint and burn', function () {
    // checking MINTING
    it('Checking mint', async function () {
      const { traceTree } = await locklift.tracing.trace(
        deployedTokenRootContract.methods
          .mint({
            amount: 333,
            recipient: callbacksContractVar.address,
            deployWalletValue: toNano(0.1),
            remainingGasTo: manager.address,
            notify: true,
            payload: '',
          })
          .send({
            from: manager.address,
            amount: toNano(5),
            bounce: true,
          }),
      );

      const transferCalls = traceTree?.findCallsForContract({
        contract: callbacksContractVar,
        name: 'onAcceptTokensMint',
      });
      console.log('Mint callback:', transferCalls);
    });

    it('Checking burn', async function () {
      const traceTreeBurn = await locklift.tracing.trace(
        deployedTokenRootContract.methods
          .burnTokens({
            amount: 100,
            walletOwner: manager.address,
            callbackTo: callbacksContractVar.address,
            remainingGasTo: manager.address,
            payload: '',
          })
          .send({
            from: manager.address,
            amount: toNano(5),
            bounce: true,
          }),
      );

      const transferCallsBurn = traceTreeBurn.traceTree!.findCallsForContract({
        contract: callbacksContractVar,
        name: 'onAcceptTokensBurn',
      });

      console.log('Burn callback:', transferCallsBurn);
    });
  });

  console.log(`Token mint/burn finished successfully ✅`);
});
