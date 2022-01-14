module.exports = {
    compiler: {
        // Path to https://github.com/broxus/TON-Solidity-Compiler
        path: '../TON-Solidity-Compiler/build/solc',
    },
    linker: {
        // Path to https://github.com/tonlabs/TVM-linker
        path: '../TVM-linker/tvm_linker/target/release/tvm_linker',
    },
    networks: {
        // You can use TON labs graphql endpoints or local node
        local: {
            ton_client: {
                // See the TON client specification for all available options
                network: {
                    server_address: 'http://localhost/',
                },
            },
            // This giver is default local-node giver
            giver: {
                address: '0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94',
                abi: {"ABI version": 1,
                    "functions": [{"name": "constructor", "inputs": [], "outputs": []}, {
                        "name": "sendGrams",
                        "inputs": [{"name": "dest", "type": "address"}, {"name": "amount", "type": "uint64"}],
                        "outputs": []
                    }],
                    "events": [],
                    "data": []
                },
                key: '',
            },
            // Use tonos-cli to generate your phrase
            // !!! Never commit it in your repos !!!
            keys: {
                phrase: '...',
                amount: 20,
            }
        },
    },
};
