import { Transaction } from 'locklift';

export const EMPTY_TVM_CELL = 'te6ccgEBAQEAAgAAAA==';

export const getRandomNonce = () => (Math.random() * 64000) | 0;

export const stringToBytesArray = (dataString: string) => {
  return Buffer.from(dataString).toString('hex');
};

export const isValidEverAddress = (address: string) =>
  /^(?:-1|0):[0-9a-fA-F]{64}$/.test(address);

export const isNumeric = (value: string) => /^-?\d+$/.test(value);

export async function sleep(ms: number) {
  ms = ms === undefined ? 1000 : ms;
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export const afterRun = async () => {
  await new Promise((resolve) => setTimeout(resolve, 120000));
};

export const Constants = {
  tokens: {
    foo: {
      name: 'Foo',
      symbol: 'Foo',
      decimals: 9,
    },
  },

  TESTS_TIMEOUT: 1200000,
};

export const displayTx = (_tx: Transaction) => {
  console.log(`txId: ${_tx.id.hash ? _tx.id.hash : _tx.id}`);
};