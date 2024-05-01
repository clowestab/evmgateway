# @ensdomains/arb-verifier

A complete Solidity library that facilitates sending CCIP-Read requests for Arbitrum state, and verifying the responses.

For a detailed readme and usage instructions, see the [monorepo readme](https://github.com/ensdomains/evmgateway/tree/main).

## How to test

1. Start the Nitro Test node. You can find instructions here: https://docs.arbitrum.io/node-running/how-tos/local-dev-node
2. Retrieve the Rollup address from the Node's Logs or by reading the configuration file of your node: `docker exec nitro-testnode-sequencer-1 cat /config/l2_chain_info.json`
3. Copy the example.env file in both arb-gateway and arb-verifier, and add the Rollup address.
4. Build the Project: `bun run build`
5. Navigate to the Arbitrum Verifier directory using `cd ./arb-verifier`.
6. Deploy the L2 test contracts: `bun run hardhat ignition deploy ignition/modules/l2/SlotDataContract.ts --network arbDevnetL2`
7. Run the verifier tests using the command `bun run run_gateway_test`.

**Note**
If you want to run the gateway in a separate process (for debugging purposes) you can run `bun run test` having started the gateway yourself `bun run start`.

## Deployments

### L2

- TestL2.sol = [0xAdef74372444e716C0473dEe1F9Cb3108EFa3818](https://goerli.arbiscan.io/address/0xAdef74372444e716C0473dEe1F9Cb3108EFa3818#code)

### L1

- ArbVerifier = [0x9E46DeE08Ad370bEFa7858c0E9a6c87f2D7E57A1](https://goerli.etherscan.io/address/0x9E46DeE08Ad370bEFa7858c0E9a6c87f2D7E57A1#code)

- TestL1.sol = [0x0d6c6B70cd561EB59e6818D832197fFad60840AB](https://goerli.etherscan.io/address/0x0d6c6B70cd561EB59e6818D832197fFad60840AB#code)

### Gateway server

- https://arb-gateway-worker.ens-cf.workers.dev

