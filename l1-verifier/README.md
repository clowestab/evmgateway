### @ensdomains/l1-verifier
A complete Solidity library that facilitates sending CCIP-Read requests for L1 state, and verifying the responses.

This repository also contains the end-to-end tests for the entire stack.

For a detailed readme and usage instructions, see the [monorepo readme](https://github.com/ensdomains/evmgateway/tree/main).

## Installation

```
bun add @ensdomains/l1-verifier
```

## How to test

There are multiple tasks available depending on which parts of the stack you want to run in independent processes (for debugging).

- `test` - you need to be running your own node *and* gateway.
- `run_node_test` - you need to run your own gateway
- `run_gateway_test` - you need to run your own node
- `run_both_test` - we got you. You need to run nothing.

Run the command using `bun` e.g. `bun run run_both_test`

Depending on which you choose you will need to run one or both a node and the `l1-gateway`.

To do so:

- node - `ganache`
- gateway - Navigate to the `l1-gateway` directory and run `bun run start`