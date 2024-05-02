import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ArbVerifier from "./ArbVerifier";

//@ts-ignore
import l2DeploymentAddresses from "../../deployments/chain-412346/deployed_addresses.json";
if (!l2DeploymentAddresses["SlotDataContract#SlotDataContract"]) { throw("Deploy L2 contracts (please)"); }

export default buildModule("SlotExamples", (m) => {

    const { arbVerifierContract } = m.useModule(ArbVerifier);
    const testL2ContractAddress = l2DeploymentAddresses["SlotDataContract#SlotDataContract"];

    const slotExamplesContract = m.contract("SlotExamples", [arbVerifierContract, testL2ContractAddress]);

    return { slotExamplesContract };
});