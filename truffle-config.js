/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * truffleframework.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

 const HDWalletProvider = require('@truffle/hdwallet-provider');
 const infuraKey1 = "c7455135455d460f91cd42510236abc3";
 const infuraKey2 = "4601d8071a0b4324a16897f3a9821831";
 const infuraKey4 = "b372dec7f4d94e5d9570b3b071b8dd31";
 const infuraKey3 = "11f9f301997640258912c47d084c7ddd";
 //
 // const fs = require('fs');
 // const mnemonic = fs.readFileSync(".secret").toString().trim();
 
 module.exports = {
   /**
    * Networks define how you connect to your ethereum client and let you set the
    * defaults web3 uses to send transactions. If you don't specify one truffle
    * will spin up a development blockchain for you on port 9545 when you
    * run `develop` or `test`. You can ask a truffle command to use a specific
    * network from the command line, e.g
    *
    * $ truffle test --network <network-name>
    */
 
   networks: {
     // Useful for testing. The `development` name is special - truffle uses it by default
     // if it's defined here and no other network is specified at the command line.
     // You should run a client (like ganache-cli, geth or parity) in a separate terminal
     // tab if you use this network and you must also set the `host`, `port` and `network_id`
     // options below to some value.
     //
     development: {
       host: '127.0.0.1', // Localhost (default: none)
       port: 8545, // Standard Ethereum port (default: none)
       network_id: '5777',
       gasPrice: 50000000000,
       gas: 6721975, // Any network (default: none)
     },
     // Another network with more advanced options...
     // advanced: {
     // port: 8777,             // Custom port
     // network_id: 1342,       // Custom network
     // gas: 8500000,           // Gas sent with each transaction (default: ~6700000)
     // gasPrice: 20000000000,  // 20 gwei (in wei) (default: 100 gwei)
     // from: <address>,        // Account to send txs from (default: accounts[0])
     // websockets: true        // Enable EventEmitter interface for web3 (default: false)
     // },
     // Useful for deploying to a public network.
     // NB: It's important to wrap the provider as a function.
     // ropsten: {
     // provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/YOUR-PROJECT-ID`),
     // network_id: 3,       // Ropsten's id
     // gas: 5500000,        // Ropsten has a lower block limit than mainnet
     // confirmations: 2,    // # of confs to wait between deployments. (default: 0)
     // timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
     // skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
     // },
     // Useful for private networks
     // private: {
     // provider: () => new HDWalletProvider(mnemonic, `https://network.io`),
     // network_id: 2111,   // This network is yours, in the cloud.
     // production: true    // Treats this network as if it was a public net. (default: false)
     // }
     mainnet: {
       network_id: '1',
       //0xA2FD306DDAf9397896Fa2a2c1588e45fA1a25b25
       provider: () => new HDWalletProvider(
         "",
         'wss://mainnet.infura.io/ws/v3/'+infuraKey1,
       ),
       gasPrice: 80000000000, // 10 gwei
       gas: 8000000,
       skipDryRun: true,
       timeoutBlocks: 80000,
     },
     ropsten: {
       network_id: '3',
       provider: () => new HDWalletProvider(
         "",
         'wss://ropsten.infura.io/ws/v3/'+infuraKey1,
       ),
       gasPrice: 10000000000, // 10 gwei
       gas: 6900000,
       skipDryRun: true,
       timeoutBlocks: 8000,
     },
     rinkeby: {
       network_id: '4',
       provider: () => new HDWalletProvider(
         "",
         'wss://rinkeby.infura.io/ws/v3/'+infuraKey2,
       ),
       gasPrice: 10000000000, // 10 gwei
       gas: 6900000,
       skipDryRun: true,
       timeoutBlocks: 80000,
     },
     oktest: {
       //0xb2F2c777BFF4228de8645d67B6F465b8cf893136
       //chainId:65
       network_id: '65',
       provider: () => new HDWalletProvider(
         "",
         'https://exchaintest.okexcn.com',
       ),
       gasPrice: 10000000000, // 2 gwei
       gas: 6900000,
       skipDryRun: true,
       timeoutBlocks: 800000,
       networkCheckTimeout: 10000000
     },
     hbtest: {
       //0xb2F2c777BFF4228de8645d67B6F465b8cf893136
       //https://http-mainnet.hecochain.com chainId:128
       network_id: '256',
       provider: () => new HDWalletProvider(
         "",
         // 'https://http-testnet.hecochain.com',
         'wss://heco-testnet.apron.network/ws/v1/c0f10914c5db40179fb86ee957820139',
       ),
       gasPrice: 10000000000, // 2 gwei
       gas: 6900000,
       skipDryRun: true,
       timeoutBlocks: 800000,
       networkCheckTimeout: 10000000
     },
     bsctest: {
       //0xb2F2c777BFF4228de8645d67B6F465b8cf893136
       //https://http-mainnet.hecochain.com chainId:128
       network_id: '97',
       provider: () => new HDWalletProvider(
         "",
         // 'https://http-testnet.hecochain.com',
         'https://data-seed-prebsc-2-s3.binance.org:8545',
       ),
       gasPrice: 10000000000, // 2 gwei
       gas: 6900000,
       skipDryRun: true,
       timeoutBlocks: 800000,
       networkCheckTimeout: 10000000
     },
     hbmain: {
       //https://http-mainnet.hecochain.com chainId:128
       network_id: '128',
       provider: () => new HDWalletProvider(
         //0x31c0bCD9D3f6b5a223633E02BD43128B12909Ec4
         "",
         'wss://heco.apron.network/ws/v1/c0f10914c5db40179fb86ee957820139',
       ),
       gasPrice: 2000000000, // 2 gwei
       gas: 6900000,
       skipDryRun: true,
       timeoutBlocks: 80000,
     },
   },
   plugins: [
     'truffle-plugin-verify'
   ],
   api_keys: {
     etherscan: 'YU4CYPYQCZJRD2N35G531RJEWGURH6VQTU'
   },
 
   // Set default mocha options here, use special reporters etc.
   mocha: {
     // timeout: 100000
   },
 
   // Configure your compilers
   
   compilers: {
     solc: {
       version: '0.6.12+commit.27d51765', // Fetch exact version from solc-bin (default: truffle's version)
       // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
       // settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: false,
          runs: 200
        },
       //  evmVersion: "byzantium"
       // }
     },
   },
 }
 