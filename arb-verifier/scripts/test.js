const {makeArbGateway} = require('../../arb-gateway');
const ethers = require('ethers');
const { Server } = require('@chainlink/ccip-read-server');

const { fork } = require('node:child_process');
require('dotenv').config()

const args = new Set(process.argv.slice(2));

const rollupAddress = process.env.ROLLUP_ADDRESS;
if (!rollupAddress) { throw("Specify the Arbitrum Rollupp address in your .env"); }

async function main() {

    const l1Provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545/");
    const l2Provider = new ethers.JsonRpcProvider("http://127.0.0.1:8547/");
   
    const gateway = await makeArbGateway(
        l1Provider,
        l2Provider,
        rollupAddress,
    );
    const server = new Server()

    gateway.add(server)
    const app = server.makeApp('/')

    app.listen(8080, function () {
        console.log(`Listening on 8080`);
    });


    console.log('Starting hardhat');
    const code = await new Promise((resolve) => {
        const hh = fork(
            '../node_modules/.bin/hardhat',
            ['test', '--network', 'arbDevnetL1'],
            {
                stdio: 'inherit',
                env: {},
            }
        );
        hh.on('close', (code) => resolve(code));
    });

    console.log('Shutting down');
    //server.close();
    process.exit(code);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});