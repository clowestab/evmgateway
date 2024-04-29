import { Server } from '@chainlink/ccip-read-server';
import { makeL1Gateway } from '../../l1-gateway';
import { HardhatEthersProvider } from '@nomicfoundation/hardhat-ethers/internal/hardhat-ethers-provider';
import type { HardhatEthersHelpers } from '@nomicfoundation/hardhat-ethers/types';
import { expect } from 'chai';
import {
  BrowserProvider,
  Contract,
  FetchRequest,
  JsonRpcProvider,
  Signer,
  ethers as ethersT,
  AbiCoder
} from 'ethers';
import { ethers } from 'hardhat';
import { EthereumProvider } from 'hardhat/types';
import request from 'supertest';

type ethersObj = typeof ethersT &
  Omit<HardhatEthersHelpers, 'provider'> & {
    provider: Omit<HardhatEthersProvider, '_hardhatProvider'> & {
      _hardhatProvider: EthereumProvider;
    };
  };

declare module 'hardhat/types/runtime' {
  const ethers: ethersObj;
  interface HardhatRuntimeEnvironment {
    ethers: ethersObj;
  }
}


//Hold contract deployment address globally
var anotherTestL2ContractAddress: any; //used for multitarget tests

describe('L1Verifier', () => {
  let provider: BrowserProvider;
  let signer: Signer;
  let verifier: Contract;
  let target: Contract;

  before(async () => {

    // 1. Hack to get a 'real' ethers provider from hardhat. The default `HardhatProvider`
    // doesn't support CCIP-read.
    // 2. If the test script has initialised a node, use that.
    // Otherwise we are running a node in a separate process for debugging - use that
    provider = process.env.RUN_NODE == "true" ? 
      new ethers.BrowserProvider(ethers.provider._hardhatProvider) : 
      new ethers.JsonRpcProvider("http://127.0.0.1:8545");

    // provider.on("debug", (x: any) => console.log(JSON.stringify(x, undefined, 2)));
    signer = await provider.getSigner(0);
    
    const l1VerifierFactory = await ethers.getContractFactory(
      'L1Verifier',
      signer
    );

    //We default to using the localhost as our gateway URL
    var ccipUrl = `http://127.0.0.1:8080/{sender}/{data}.json`;

    //If we are NOT running a local gateway we will spawn one
    if (process.env.RUN_GATEWAY == "true") {

      console.log("Spawning a gateway");

      //And update the CCIP read gateway IRL
      ccipUrl = "test:";

      const gateway = makeL1Gateway(provider as unknown as JsonRpcProvider);
      const server = new Server();
      gateway.add(server);
      const app = server.makeApp('/');
      const getUrl = FetchRequest.createGetUrlFunc();
      ethers.FetchRequest.registerGetUrl(async (req: FetchRequest) => {
        if (req.url != 'test:') return getUrl(req);

        const r = request(app).post('/');
        if (req.hasBody()) {
          r.set('Content-Type', 'application/json').send(
            ethers.toUtf8String(req.body)
          );
        }
        const response = await r;
        return {
          statusCode: response.statusCode,
          statusMessage: response.ok ? 'OK' : response.statusCode.toString(),
          body: ethers.toUtf8Bytes(JSON.stringify(response.body)),
          headers: {
            'Content-Type': 'application/json',
          },
        };
      });      
    }

    console.log("CCIP URL", ccipUrl);

    verifier = await l1VerifierFactory.deploy([ccipUrl]);
    
    //Deploy a second target contract
    const anotherTestL2ContractFactory = await ethers.getContractFactory('AnotherTestL2', signer);
    const anotherTestL2Contract = await anotherTestL2ContractFactory.deploy();
    anotherTestL2ContractAddress = await anotherTestL2Contract.getAddress();

    console.log("anotherTestL2ContractAddress", anotherTestL2ContractAddress);

    //Deploy our core data contract with various types of static/dynamic data in storage slots
    const slotDataContractFactory = await ethers.getContractFactory('SlotDataContract', signer);
    const slotDataContract = await slotDataContractFactory.deploy(
      anotherTestL2ContractAddress //pass in our other contract address
    );
    const slotDataContractAddress = await slotDataContract.getAddress();

    console.log("slotDataContractAddress", slotDataContractAddress);

    //Deploy the test resolution contract
    const testL1Factory = await ethers.getContractFactory('SlotExamples', signer);
    target = await testL1Factory.deploy(
      await verifier.getAddress(),
      await slotDataContractAddress
    );
    // Mine an empty block so we have something to prove against
    await provider.send('evm_mine', []);
  });

  it.only('returns a static value', async () => {

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

  //TOM playing
  it('memory arrays', async () => {

    const result = await target.memoryArrays(["0x00"], { enableCcipRead: true });
  });
});
