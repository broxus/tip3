const { docgen } = require('solidity-docgen');
const config = require('../../docs/config');

async function main() {
  await docgen([], config);
}

main();
