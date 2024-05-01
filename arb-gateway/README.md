# @ensdomains/arb-gateway

An instantiation of [evm-gateway](https://github.com/ensdomains/evmgateway/tree/main/evm-gateway) that targets Arbitrum - that is, it implements a CCIP-Read gateway that generates proofs of contract state on Arbitrum.

For a detailed readme and usage instructions, see the [monorepo readme](https://github.com/ensdomains/evmgateway/tree/main).

To get started, you need to have an RPC URL for both Ethereum Mainnet and Arbitrum. You also need to provide an L2_ROLLUP address which is the Rollup contract deployed on Mainnet or the Nitro Node.

## How to use arb-gateway locally via cloudflare dev env (aka wrangler)

```
cd arb-gateway
npm install -g bun wrangler
bun install
touch .dev.vars
## set L1_PROVIDER_URL, L2_PROVIDER_URL, L2_ROLLUP
bun run dev
```

## How to deploy arb-gateway to cloudflare

```
cd arb-gateway
npm install -g wrangler
wrngler login

wrangler secret put L1_PROVIDER_URL --env sepolia
wrangler secret put L2_PROVIDER_URL --env sepolia
wrangler secret put L2_ROLLUP --env sepolia
wrangler secret put ENDPOINT_URL --env sepolia
yarn deploy --env sepolia
```

## How to test

- See the [arb-verifier](https://github.com/ensdomains/evmgateway/tree/main/arb-verifier) README.
