import {
  Address,
  Contract,
  Giver,
  LockliftConfig,
  ProviderRpcClient,
  Transaction,
} from 'locklift';
import { FactorySource } from './build/factorySource';
import { Deployments } from 'locklift-deploy';
import 'locklift-verifier';
import 'locklift-deploy';
import * as dotenv from 'dotenv';

dotenv.config();

declare global {
  // eslint-disable-next-line @typescript-eslint/ban-ts-comment
  // @ts-ignore
  const locklift: import('locklift').Locklift<FactorySource>;
}

declare module 'locklift' {
  // eslint-disable-next-line @typescript-eslint/ban-ts-comment
  // @ts-ignore
  export interface Locklift {
    deployments: Deployments<FactorySource>;
  }
}

const config: LockliftConfig = {
  compiler: {
    version: '0.62.0',
    externalContracts: {
      precompiled: ['TokenWalletPlatform'],
    },
  },
  verifier: {
    verifierVersion: 'latest',
    apiKey: process.env.EVERSCAN_API_KEY ?? '',
    secretKey: process.env.EVERSCAN_SECRET_KEY ?? '',
  },
  linker: { version: '0.15.48' },
  networks: {
    local: {
      connection: {
        id: 1,
        group: 'localnet',
        type: 'graphql',
        data: {
          endpoints: [process.env.LOCAL_NETWORK_ENDPOINT ?? ''],
          latencyDetectionInterval: 1000,
          local: true,
        },
      },
      giver: {
        address: process.env.LOCAL_GIVER_ADDRESS ?? '',
        key: process.env.LOCAL_GIVER_KEY ?? '',
      },
      tracing: { endpoint: process.env.LOCAL_NETWORK_ENDPOINT ?? '' },
      keys: {
        phrase: process.env.LOCAL_PHRASE,
        amount: 20,
      },
    },
    test: {
      connection: {
        id: 1,
        type: 'graphql',
        group: 'dev',
        data: {
          endpoints: [process.env.DEVNET_NETWORK_ENDPOINT ?? ''],
          latencyDetectionInterval: 1000,
          local: false,
        },
      },
      giver: {
        address: process.env.DEVNET_GIVER_ADDRESS ?? '',
        key: process.env.DEVNET_GIVER_KEY ?? '',
      },
      tracing: { endpoint: process.env.DEVNET_NETWORK_ENDPOINT ?? '' },
      keys: {
        phrase: process.env.DEVNET_PHRASE,
        amount: 20,
      },
    },
    venom_testnet: {
      connection: {
        id: 1000,
        type: 'jrpc',
        group: 'dev',
        data: {
          endpoint: process.env.VENOM_TESTNET_RPC_NETWORK_ENDPOINT ?? '',
        },
      },
      giver: {
        address: process.env.VENOM_TESTNET_GIVER_ADDRESS ?? '',
        phrase: process.env.VENOM_TESTNET_GIVER_PHRASE ?? '',
        accountId: 0,
      },
      tracing: {
        endpoint: process.env.VENOM_TESTNET_GQL_NETWORK_ENDPOINT ?? '',
      },
      keys: {
        phrase: process.env.VENOM_TESTNET_PHRASE,
        amount: 20,
      },
    },
    main: {
      connection: {
        id: 1,
        type: 'jrpc',
        group: 'dev',
        data: {
          endpoint: process.env.MAINNET_RPC_NETWORK_ENDPOINT ?? '',
        },
      },
      giver: {
        address: process.env.MAINNET_GIVER_ADDRESS ?? '',
        key: process.env.MAINNET_GIVER_KEY ?? '',
      },
      tracing: { endpoint: process.env.MAINNET_GQL_NETWORK_ENDPOINT ?? '' },
      keys: {
        phrase: process.env.MAINNET_PHRASE,
        amount: 20,
      },
    }
  },
  mocha: {
    timeout: 3000000,
    bail: true,
  },
};

export class GiverV1 implements Giver {
  public giverContract: Contract<typeof GIVER_V1_ABI>;

  constructor(ever: ProviderRpcClient, address: string) {
    const giverAddr = new Address(address);
    this.giverContract = new ever.Contract(GIVER_V1_ABI, giverAddr);
  }

  public async sendTo(
    sendTo: Address,
    value: string,
  ): Promise<{ transaction: Transaction; output?: any }> {
    return this.giverContract.methods
      .sendGrams({
        amount: value,
        dest: sendTo,
      })
      .sendExternal({ withoutSignature: true });
  }
}

const GIVER_V1_ABI = {
  'ABI version': 1,
  functions: [
    { name: 'constructor', inputs: [], outputs: [] },
    {
      name: 'sendGrams',
      inputs: [
        { name: 'dest', type: 'address' },
        { name: 'amount', type: 'uint64' },
      ],
      outputs: [],
    },
  ],
  events: [],
  data: [],
} as const;

export default config;
