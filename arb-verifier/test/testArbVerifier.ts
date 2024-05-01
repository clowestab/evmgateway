import { expect } from 'chai';
import {
  Contract,
  AbiCoder,
  ethers
} from 'ethers';
import hre from 'hardhat';

import SlotExamples from '../ignition/modules/l1/SlotExamples';
import l2DeploymentAddresses from "../ignition/deployments/chain-412346/deployed_addresses.json";


describe('ArbVerifier', () => {
  let target: Contract;

  const slotDataContractAddress = l2DeploymentAddresses["SlotDataContract#SlotDataContract"];
  const anotherTestL2ContractAddress = l2DeploymentAddresses["AnotherTestL2#AnotherTestL2"];

  if (!slotDataContractAddress) { throw("No Deployment address for main L2 target"); }
  if (!anotherTestL2ContractAddress) { throw("No Deployment address for second L2 target"); }

  before(async () => {

    const l1Provider = new ethers.JsonRpcProvider((hre.network.config as any).url);

    const slotExamples = await hre.ignition.deploy(SlotExamples);
    target = slotExamples.slotExamplesContract.connect(l1Provider) as typeof slotExamples.slotExamplesContract
  })

  it('returns a static value', async () => {
    const result = await target.getLatest({ enableCcipRead: true });
    expect(Number(result)).to.equal(49);
  });

  it('get padded address', async () => {
    const result = await target.getPaddedAddress({ enableCcipRead: true });
    const expectedAddress: any = (anotherTestL2ContractAddress.replace("0x", "0x0000000000000000") + "00000038").toLowerCase();

    expect(result).to.equal(
      expectedAddress
    );
  });

  it('get sliced padded address', async () => {
    const result = await target.getStringBytesUsingAddressSlicedFromBytes({ enableCcipRead: true });

    expect(result).to.equal(
      "0x746f6d"
    );
  });

  it('get two static values from two different targets', async () => {
      const result = await target.getLatestFromTwo(anotherTestL2ContractAddress!, { enableCcipRead: true });

      const decodedResult = AbiCoder.defaultAbiCoder().decode(['uint256'], result[0][0]);
      const decodedResultTwo = AbiCoder.defaultAbiCoder().decode(['uint256'], result[1][0]);

      expect(decodedResult[0]).to.equal(
        49n
      );

      expect(decodedResultTwo[0]).to.equal(
        262n
      );
  });

  it('returns a string from a storage slot on a target', async () => {
    const result = await target.getName({ enableCcipRead: true });
    expect(result).to.equal('Satoshi');
  });

  it('returns an array of strings from two different storage slots on the target', async () => {
    const result = await target.getNameTwice({ enableCcipRead: true });
    expect(result).to.eql([ 'Satoshi', 'tomiscool' ]);
  });

  it('gets a value from an mapping using a string key', async () => {
      const result = await target.getStringAndStringFromMapping({ enableCcipRead: true });
      expect(result).to.equal(
        'clowes'
      );
  });

  it('get a dynamic string value using a key that is sliced from the previously returned value', async () => {
      const result = await target.getHighscorerFromRefSlice({ enableCcipRead: true });
      expect(result).to.equal(
        'Hal Finney'
      );
  });

  it('get an address by slicing part of a previously fetched value', async () => {
    const result = await target.getValueFromAddressFromRef({ enableCcipRead: true });
    expect(Number(result)).to.equal(262);
  });

  it('slice', async () => {
    const result = await target.getValueFromAddressFromRefSlice({ enableCcipRead: true });
    expect(Number(result)).to.equal(262);
  });
  
  it('get a dynamic value from a mapping keyed on uint256', async () => {
    const result = await target.getHighscorer(49, { enableCcipRead: true });
    expect(result).to.equal('Hal Finney');
  });

  it('get a long (multi slot) dynamic value from a mapping keyed on uint256', async () => {
    const result = await target.getHighscorer(1, { enableCcipRead: true });
    expect(result).to.equal(
      'Hubert Blaine Wolfeschlegelsteinhausenbergerdorff Sr.'
    );
  });

  it('get static value from mapping using lookbehind to reference value', async () => {
    const result = await target.getLatestHighscore({ enableCcipRead: true });
    expect(Number(result)).to.equal(12345);
  });

  it('get dynamic value from mapping using lookbehind to reference value', async () => {
    const result = await target.getLatestHighscorer({ enableCcipRead: true });
    expect(result).to.equal('Hal Finney');
  });

  it('mappings with variable-length keys', async () => {
    const result = await target.getNickname('Money Skeleton', {
      enableCcipRead: true,
    });
    expect(result).to.equal('Vitalik Buterin');
  });

  it('nested proofs of mappings with variable-length keys', async () => {
    const result = await target.getPrimaryNickname({ enableCcipRead: true });
    expect(result).to.equal('Hal Finney');
  });

  it('treats uninitialized storage elements as zeroes', async () => {
    const result = await target.getZero({ enableCcipRead: true });
    expect(Number(result)).to.equal(0);
  });

  it('treats uninitialized dynamic values as empty strings', async () => {
    const result = await target.getNickname('Santa', { enableCcipRead: true });
    expect(result).to.equal('');
  });

  it('will index on uninitialized values', async () => {
    const result = await target.getZeroIndex({ enableCcipRead: true });
    expect(Number(result)).to.equal(1);
  })
});
