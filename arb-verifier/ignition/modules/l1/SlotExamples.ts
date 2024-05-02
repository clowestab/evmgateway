import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ArbVerifier from "./ArbVerifier";
import {existsSync, readFileSync} from "fs"
import path from 'path';

const deploymentsPath = path.resolve(__dirname, "../../deployments/chain-412346/deployed_addresses.json");

if (!existsSync(deploymentsPath)) {
    throw("Deploy L2 contracts (please) wut");
}

const l2DeploymentAddresses = JSON.parse(readFileSync(deploymentsPath, 'utf8'));
if (!l2DeploymentAddresses["SlotDataContract#SlotDataContract"]) { throw("Deploy L2 contracts (please)"); }


export default buildModule("SlotExamples", (m) => {

    const { arbVerifierContract } = m.useModule(ArbVerifier);
    const testL2ContractAddress = l2DeploymentAddresses["SlotDataContract#SlotDataContract"];

    const slotExamplesContract = m.contract("SlotExamples", [arbVerifierContract, testL2ContractAddress]);

    return { slotExamplesContract };
});