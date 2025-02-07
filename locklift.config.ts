import {
  LockliftConfig,
} from 'locklift';
import { FactorySource } from './build/factorySource';
import { Deployments } from '@broxus/locklift-deploy';
import '@broxus/locklift-verifier';
import '@broxus/locklift-deploy';
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
    version: '0.71.0',
    externalContracts: {
      precompiled: ['TokenWalletPlatform'],
    },
  },
  verifier: {
    verifierVersion: 'latest',
    apiKey: process.env.EVERSCAN_API_KEY ?? '',
    secretKey: process.env.EVERSCAN_SECRET_KEY ?? '',
  },
  linker: { version: '0.20.6' },
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
      keys: {
        phrase: process.env.LOCAL_PHRASE,
        amount: 20,
      },
    },
    locklift: {
      giver: {
        address: process.env.LOCAL_GIVER_ADDRESS!,
        key: process.env.LOCAL_GIVER_KEY!,
      },
      connection: {
        id: 1001,
        type: 'proxy',
        // eslint-disable-next-line @typescript-eslint/ban-ts-comment
        // @ts-ignore
        data: {},
      },
      keys: {
        phrase: process.env.LOCAL_PHRASE,
        amount: 20,
      },
    },
  },
  mocha: {
    timeout: 3000000,
    bail: true,
  },
};

export default config;
