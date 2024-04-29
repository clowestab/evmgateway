const hre = require("hardhat");

async function main() {
  const accounts = await hre.ethers.getSigners();

  const Verifier = await hre.ethers.getContractFactory("L1Verifier");
  // Deploy the contract
  const verifierContract = await Verifier.deploy(["http://localhost:8080/{sender}/{data}.json"]);

  await verifierContract.deployed();
  
  const verifierAddress = await verifierContract.getAddress();

  console.log("verifierContract", verifierAddress);

  //The 42 in slot 0 contract
  const SlotTest = await hre.ethers.getContractFactory("SlotTest");
  const slotContract = await SlotTest.deploy();

  const slotContractAddress = await slotContract.getAddress();

  console.log("slotContract", slotContractAddress);

  const TestSlot = await hre.ethers.getContractFactory("TestSlot");
  const testSlotContract = await TestSlot.deploy(verifierAddress, slotContractAddress);

  const testSlotContractAddress = await testSlotContract.getAddress();

  console.log("testSlotContract", testSlotContractAddress);

  const secondTargetAddress = "0x00777F1b1439BDc7Ad1d4905A38Ec9f5400e0e26";

  console.log("hre.ethers", hre.ethers.version);
  console.log("hre.ethers2", hre.ethers.provider);

  testSlotContract.getLatestFromTwo(secondTargetAddress, { enableCcipRead: true });

  
  console.log("t", t);
    // Wait for the deployment transaction to be mined
    //await contract.deployed();

    //console.log(`TestSlot deployed to: ${contract.address}`);


/*
  for (const account of accounts) {
    console.log(account.address);
  }
  */
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});