import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import 'dotenv/config'

const GATEWAY_URLS = {
    arbDevnetL1: 'http://localhost:8089/{sender}/{data}.json',
    goerli: 'https://arb-gateway-worker.ens-cf.workers.dev/{sender}/{data}.json',
};
  
const ROLLUP_ADDRESSES = {
    goerli: '',
};

const ROLLUP_ADDRESS = process.env["ROLLUP_ADDRESS"];

if (!ROLLUP_ADDRESS) { throw("Please run an Arbitrum devnet and provide the ROLLUP_ADDRESS in .env"); }

export default buildModule("ArbVerifier", (m) => {

    const arbVerifierContract = m.contract("ArbVerifier", [["http://127.0.0.1:8080/{sender}/{data}.json"], ROLLUP_ADDRESS]);

    return { arbVerifierContract };
});