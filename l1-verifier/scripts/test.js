const { fork } = require('node:child_process');
const ganache = require('ganache');
const options = {
  logging: {
    quiet: true,
  }
};

const args = new Set(process.argv.slice(2));

async function main() {

  var port = 8545;

  if (args.has("run-node")) {
    const server = ganache.server(options);
    console.log('Starting local Ganache node');
    port = await new Promise((resolve, reject) => {
      server.listen(8545, async (err) => {
        console.log(`Listening on port ${server.address().port}`);
        if (err) reject(err);
        resolve(server.address().port);
      });
    });
  }


  console.log('Starting hardhat');
  const code = await new Promise((resolve) => {
    const hh = fork(
      '../node_modules/.bin/hardhat',
      ['test', '--network', 'ganache'],
      {
        stdio: 'inherit',
        env: {
          RPC_PORT: port.toString(),
          RUN_NODE: args.has("run-node"),
          RUN_GATEWAY: args.has("run-gateway")
        },
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