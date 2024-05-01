import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import AnotherTestL2 from "./AnotherTestL2";

export default buildModule("SlotDataContract", (m) => {

    const account1 = m.getAccount(0);

    const { anotherTestL2Contract } = m.useModule(AnotherTestL2);

    const slotDataContract = m.contract("SlotDataContract", [anotherTestL2Contract], { from: account1 });

    return { slotDataContract };
});