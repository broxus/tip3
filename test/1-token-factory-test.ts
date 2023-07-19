import { lockliftChai, toNano, zeroAddress } from 'locklift';
import BigNumber from 'bignumber.js';
import {
  TokenFactoryAbi,
  TokenRootUpgradeableAbi,
  TokenWalletPlatformAbi,
  TokenWalletUpgradeableAbi,
} from '../build/factorySource';
import chai, { expect } from 'chai';
import { ContractData } from 'locklift/internal/factory';

chai.use(lockliftChai);

describe('Testing token factory data', async function () {
  console.log('0-TOKEN-FACTORY-TEST');

  // Load contract factory
  let TokenFactory: ContractData<TokenFactoryAbi>;

  let TokenWallet: ContractData<TokenWalletUpgradeableAbi>;
  let TokenRoot: ContractData<TokenRootUpgradeableAbi>;
  let TokenWalletPlatform: ContractData<TokenWalletPlatformAbi>;

  it('Check Token factory abis and codes', async function () {
    await locklift.deployments.fixture({
      include: ['factory-account'],
    });

    TokenFactory = locklift.factory.getContractArtifacts('TokenFactory');
    TokenWallet = locklift.factory.getContractArtifacts(
      'TokenWalletUpgradeable',
    );
    TokenRoot = locklift.factory.getContractArtifacts('TokenRootUpgradeable');
    TokenWalletPlatform = locklift.factory.getContractArtifacts(
      'TokenWalletPlatform',
    );

    expect(TokenFactory.code).not.to.equal(
      undefined,
      'TokenFactory Code should be available',
    );
    expect(TokenFactory.abi).not.to.equal(
      undefined,
      'TokenFactory ABI should be available',
    );

    expect(TokenRoot.abi).not.to.equal(
      undefined,
      'TokenRoot ABI should be available',
    );
    expect(TokenFactory.code).not.to.equal(
      undefined,
      'TokenRoot Code should be available',
    );

    expect(TokenWallet.abi).not.to.equal(
      undefined,
      'TokenWallet ABI should be available',
    );
    expect(TokenWallet.code).not.to.equal(
      undefined,
      'TokenWallet Code should be available',
    );

    expect(TokenWalletPlatform.abi).not.to.equal(
      undefined,
      'TokenWalletPlatform ABI should be available',
    );
    expect(TokenWalletPlatform.code).not.to.equal(
      undefined,
      'TokenWalletPlatform Code should be available',
    );
  });

  it('Check factory Token creation', async function () {
    const tokenFactory =
      locklift.deployments.getContract<TokenFactoryAbi>(`TokenFactory`);

    console.log(`TokenFactory address: ${tokenFactory.address.toString()} ✅`);

    // Check deployed contracts
    expect(tokenFactory.address.toString())
      .to.be.a('string')
      .and.satisfy((s: string) => s.startsWith('0:'), 'Bad future address');
    expect(
      (await tokenFactory.methods.rootCode({ answerId: 0 }).call()).value0,
    ).to.equal(TokenRoot.code, 'Wrong token root code');
    expect(
      (await tokenFactory.methods.walletCode({ answerId: 0 }).call()).value0,
    ).to.equal(TokenWallet.code, 'Wrong token wallet code');
    expect(
      (await tokenFactory.methods.walletPlatformCode({ answerId: 0 }).call())
        .value0,
    ).to.equal(TokenWalletPlatform.code, 'Wrong platform code');

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

    console.log('Deployed factory contracts are fine ✅');

    // Interacting with deployed contracts
    const manager = locklift.deployments.getAccount('ManagerAccount').account;
    const tokensToCreate = [
      {
        name: 'Test 1',
        symbol: 'TST1',
        decimals: 3,
        owner: manager.address,
        amount: 10,
        mintDisabled: false,
        burnByRootDisabled: false,
        burnPaused: false,
        initialSupplyTo: zeroAddress,
        initialSupply: '0',
        deployWalletValue: '0',
      },
      {
        name: 'Test 2',
        symbol: 'TST2',
        decimals: 4,
        owner: manager.address,
        amount: 10,
        mintDisabled: true,
        burnByRootDisabled: true,
        burnPaused: true,
        initialSupplyTo: manager.address,
        initialSupply: '100',
        deployWalletValue: toNano(0.1),
      },
    ];

    for (const tokenData of tokensToCreate) {
      const index = tokensToCreate.indexOf(tokenData);

      await tokenFactory.methods
        .createToken({
          callId: index,
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

      const deployedTokenRoot = await latestCreatedRoot();
      console.log(`Deployed ${tokenData.symbol}: ${deployedTokenRoot}`);

      expect(deployedTokenRoot.toString())
        .to.be.a('string')
        .and.not.equal(zeroAddress, 'Bad Token Root address');

      await locklift.deployments.saveContract({
        contractName: 'TokenRootUpgradeable',
        deploymentName: `TokenRoot${index}`,
        address: deployedTokenRoot,
      });

      const deployedTokenRootContract =
        await locklift.deployments.getContract<TokenRootUpgradeableAbi>(
          `TokenRoot${index}`,
        );
      const name = (
        await deployedTokenRootContract.methods.name({ answerId: 0 }).call()
      ).value0;
      const symbol = (
        await deployedTokenRootContract.methods.symbol({ answerId: 0 }).call()
      ).value0;
      const decimals = (
        await deployedTokenRootContract.methods.decimals({ answerId: 0 }).call()
      ).value0;
      const owner = (
        await deployedTokenRootContract.methods
          .rootOwner({ answerId: 0 })
          .call()
      ).value0;
      const mintDisabled = (
        await deployedTokenRootContract.methods
          .mintDisabled({ answerId: 0 })
          .call()
      ).value0;
      const burnByRootDisabled = (
        await deployedTokenRootContract.methods
          .burnByRootDisabled({ answerId: 0 })
          .call()
      ).value0;
      const burnPaused = (
        await deployedTokenRootContract.methods
          .burnPaused({ answerId: 0 })
          .call()
      ).value0;

      const walletCode = (
        await deployedTokenRootContract.methods
          .walletCode({ answerId: 0 })
          .call()
      ).value0;
      const platformCode = (
        await deployedTokenRootContract.methods
          .platformCode({ answerId: 0 })
          .call()
      ).value0;

      if (tokenData.initialSupplyTo !== zeroAddress) {
        const totalSupply = (
          await deployedTokenRootContract.methods
            .totalSupply({ answerId: 0 })
            .call()
        ).value0;
        const wallet = await deployedTokenRootContract.methods
          .walletOf({
            walletOwner: tokenData.initialSupplyTo,
            answerId: 0,
          })
          .call();

        await locklift.deployments.saveContract({
          contractName: 'TokenWalletUpgradeable',
          deploymentName: `Wallet${index}`,
          address: wallet.value0,
        });
        const tokenWalletContract =
          await locklift.deployments.getContract<TokenWalletUpgradeableAbi>(
            `Wallet${index}`,
          );
        const balance = (
          await tokenWalletContract.methods.balance({ answerId: 0 }).call()
        ).value0;

        console.log(balance, 'balance');
        expect(
          new BigNumber(tokenData.initialSupply)
            .shiftedBy(tokenData.decimals)
            .toString(),
        ).to.equal(
          totalSupply.toString(),
          'Wrong totalSupply in deployed Token',
        );
        expect(
          new BigNumber(tokenData.initialSupply)
            .shiftedBy(tokenData.decimals)
            .toString(),
        ).to.equal(balance.toString(), 'Wrong initialSupply of deployed Token');
      }

      expect(name).to.equal(
        tokenData.name,
        'Wrong Token name in deployed Token',
      );
      expect(symbol).to.equal(
        tokenData.symbol,
        'Wrong Token symbol in deployed Token',
      );
      expect(Number(decimals)).to.equal(
        tokenData.decimals,
        'Wrong Token decimals in deployed Token',
      );
      expect(owner.toString()).to.equal(
        tokenData.owner.toString(),
        'Wrong Token owner in deployed Token',
      );
      expect(mintDisabled).to.equal(
        tokenData.mintDisabled,
        'Wrong Token owner in deployed Token',
      );
      expect(burnByRootDisabled).to.equal(
        tokenData.burnByRootDisabled,
        'Wrong Token owner in deployed Token',
      );
      expect(burnPaused).to.equal(
        tokenData.burnPaused,
        'Wrong Token owner in deployed Token',
      );
      expect(walletCode).to.equal(
        TokenWallet.code,
        'Wrong Token Wallet code in deployed Token',
      );
      expect(platformCode).to.equal(
        TokenWalletPlatform.code,
        'Wrong Platform code in deployed Token',
      );

      console.log(`Token ${tokenData.symbol} checked ✅`);
    }
  });
  console.log(`Token factory test finished successfully ✅`);
});
