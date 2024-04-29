import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";

export default buildModule("L1Verifier", async (m) => {

  const l1VerifierContract = m.contract("L1Verifier", [["http://localhost:8080/{sender}/{data}.json"]]);

  const slotDataContract = m.contract("SlotDataContract");

  const slotExamplesContract = m.contract("SlotExamples", [l1VerifierContract, slotDataContract]);

  //m.call(apollo, "launch", []);

  const p = new ethers.JsonRpcProvider("http://localhost:8545");
  const instance = new ethers.Contract("0x6F6272145c28b26dC4e3Dac52E17B41C560B49A5", ["function getLatestFromTwo(address) public view returns(bytes[][])"], p)

const value = await instance["getLatestFromTwo"]("0x00777F1b1439BDc7Ad1d4905A38Ec9f5400e0e26", { enableCcipRead: true })
  return { l1VerifierContract, slotDataContract, slotExamplesContract };
});