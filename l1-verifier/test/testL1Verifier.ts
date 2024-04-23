import { Server } from '@chainlink/ccip-read-server';
import { makeL1Gateway } from '@ensdomains/l1-gateway';
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
    // Hack to get a 'real' ethers provider from hardhat. The default `HardhatProvider`
    // doesn't support CCIP-read.
    provider = new ethers.BrowserProvider(ethers.provider._hardhatProvider);
    // provider.on("debug", (x: any) => console.log(JSON.stringify(x, undefined, 2)));
    signer = await provider.getSigner(0);
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
    const l1VerifierFactory = await ethers.getContractFactory(
      'L1Verifier',
      signer
    );
    //verifier = await l1VerifierFactory.deploy(['test:']);
    //Lets deploy to a locally running ganache node such that we can play
    verifier = await l1VerifierFactory.deploy(["http://localhost:8080/{sender}/{data}.json"]);

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

  //DONE2
  it('returns a static value', async () => {

    const result = await target.getLatest({ enableCcipRead: true });
    expect(Number(result)).to.equal(49);
  });

  //DONE2
  it('get padded address', async () => {

    const result = await target.getPaddedAddress({ enableCcipRead: true });

    const expectedAddress: any = (anotherTestL2ContractAddress.replace("0x", "0x0000000000000000") + "00000038").toLowerCase();

    expect(result).to.equal(
      expectedAddress
    );

  });

  //DONE2
  it('get sliced padded address', async () => {

    const result = await target.getStringBytesUsingAddressSlicedFromBytes({ enableCcipRead: true });

    expect(result).to.equal(
      "0x746f6d"
    );

  });


  //DONE2
  it('get two static values from two different targets', async () => {

      const result = await target.getLatestFromTwo(anotherTestL2ContractAddress!, { enableCcipRead: true });

      console.log("result", result);
      const decodedResult = AbiCoder.defaultAbiCoder().decode(['uint256'], result[0][0]);
      const decodedResultTwo = AbiCoder.defaultAbiCoder().decode(['uint256'], result[1][0]);

      expect(decodedResult[0]).to.equal(
        49n
      );

      expect(decodedResultTwo[0]).to.equal(
        262n
      );
  });

  //DONE2
  it('returns a string from a storage slot on a target', async () => {

    const result = await target.getName({ enableCcipRead: true });

    expect(result).to.equal('Satoshi');
  });

  //DONE2
  it('returns an array of strings from two different storage slots on the target', async () => {

    const result = await target.getNameTwice({ enableCcipRead: true });

    console.log(result);

    expect(result).to.eql([ 'Satoshi', 'tomiscool' ]);
  });

  //DONE2
  it('gets a value from an mapping using a string key', async () => {

      const result = await target.getStringAndStringFromMapping({ enableCcipRead: true });
      expect(result).to.equal(
        'clowes'
      );


  });

  //DONE2
  it('get a dynamic string value using a key that is sliced from the previously returned value', async () => {

      const result = await target.getHighscorerFromRefSlice({ enableCcipRead: true });
      expect(result).to.equal(
        'Hal Finney'
      );
  });

  
  //NOT wip
  it('get an address by slicing part of a previously fetched value', async () => {

    //try {
    const result = await target.getValueFromAddressFromRef({ enableCcipRead: true });
    expect(Number(result)).to.equal(262);
  
    //} catch (e) {
    //  console.log(e);
    //  const iface = new ethers.Interface(["error Problem(bytes)"]);
    //  const erro = iface.decodeErrorResult("Problem", e.data)
  
    //  console.log(erro);
  
      //ans -   '0x000000000000000000000000000000000000000000000000000000000000002a' - succeeds
      //alt - Result(1) [ '0x2a' ] - fails
    //}
  });

  //NOT
  it('slice', async () => {
    
    //try {
    const result = await target.getValueFromAddressFromRefSlice({ enableCcipRead: true });
    expect(Number(result)).to.equal(262);
  
    //} catch (e) {
    //  console.log(e);
    //  const iface = new ethers.Interface(["error Problem(bytes)"]);
    //  const erro = iface.decodeErrorResult("Problem", e.data)
  
    //  console.log(erro);
  
      //ans -   '0x000000000000000000000000000000000000000000000000000000000000002a' - succeeds
      //alt - Result(1) [ '0x2a' ] - fails
    //}
  });
  
  //DONE2
  it('get a dynamic value from a mapping keyed on uint256', async () => {
    const result = await target.getHighscorer(49, { enableCcipRead: true });
    expect(result).to.equal('Hal Finney');
  });

  //DONE2
  it('get a long (multi slot) dynamic value from a mapping keyed on uint256', async () => {
    const result = await target.getHighscorer(1, { enableCcipRead: true });
    expect(result).to.equal(
      'Hubert Blaine Wolfeschlegelsteinhausenbergerdorff Sr.'
    );
  });

  //DONE2
  it('get static value from mapping using lookbehind to reference value', async () => {
    const result = await target.getLatestHighscore({ enableCcipRead: true });
    expect(Number(result)).to.equal(12345);
  });

  //DONE
  it('get dynamic value from mapping using lookbehind to reference value', async () => {
    const result = await target.getLatestHighscorer({ enableCcipRead: true });
    expect(result).to.equal('Hal Finney');
  });

  //DONE
  it('mappings with variable-length keys', async () => {
    const result = await target.getNickname('Money Skeleton', {
      enableCcipRead: true,
    });
    expect(result).to.equal('Vitalik Buterin');
  });

  //DONE
  it('nested proofs of mappings with variable-length keys', async () => {
    const result = await target.getPrimaryNickname({ enableCcipRead: true });
    expect(result).to.equal('Hal Finney');
  });

  //DONE
  it('treats uninitialized storage elements as zeroes', async () => {
    const result = await target.getZero({ enableCcipRead: true });
    expect(Number(result)).to.equal(0);
  });

  //DONE
  it('treats uninitialized dynamic values as empty strings', async () => {
    const result = await target.getNickname('Santa', { enableCcipRead: true });
    expect(result).to.equal('');
  });

  //DONE
  it('will index on uninitialized values', async () => {
    const result = await target.getZeroIndex({ enableCcipRead: true });
    expect(Number(result)).to.equal(1);
  })


  //TOM playing
  it('memory arrays', async () => {

    const result = await target.memoryArrays(["0x00"], { enableCcipRead: true });
  });
});
