import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ArbVerifier from "./ArbVerifier";

export default buildModule("SlotExamples", (m) => {

    const { arbVerifierContract } = m.useModule(ArbVerifier);
    const testL2ContractAddress = "0x514aDac2D6baf50B1c349658848D76a9A6Ff9484";

    const slotExamplesContract = m.contract("SlotExamples", [arbVerifierContract, testL2ContractAddress]);

    return { slotExamplesContract };
});