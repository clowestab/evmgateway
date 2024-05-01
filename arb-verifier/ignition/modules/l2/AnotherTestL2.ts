import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("AnotherTestL2", (m) => {

    const account1 = m.getAccount(0);

    const anotherTestL2Contract = m.contract("AnotherTestL2", [], { from: account1 });

    return { anotherTestL2Contract };
});