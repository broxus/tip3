const { defaultDocgen } = require('tsolidity-docgen');
const config = require('./../docs/config');

async function main() {
  await defaultDocgen(config);
}

main();
