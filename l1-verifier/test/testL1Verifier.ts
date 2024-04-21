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

var l2ContractAddress;

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

    //Deploy a contract with various types of static/dynamic data in storage slots
    const testL2Factory = await ethers.getContractFactory('TestL2', signer);
    const l2Contract = await testL2Factory.deploy();
    l2ContractAddress = await l2Contract.getAddress();

    console.log("l2ContractAddress", l2ContractAddress);

    const anotherContractFactory = await ethers.getContractFactory('AnotherTestL2', signer);
    const anotherContract = await anotherContractFactory.deploy();
    const anotherContractAddress = await anotherContract.getAddress();

    console.log("anotherContractAddress", anotherContractAddress);

    //Deploy another contract with various types of static/dynamic data in storage slots
    const slotDataContractFactory = await ethers.getContractFactory('SlotDataContract', signer);
    const slotDataContract = await slotDataContractFactory.deploy(
      anotherContractAddress
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

    expect(result).to.equal(
      "0x00000000000000008e674b194c868ea762e488a835695608cc170a6c00000038"
    );

  });

  //DONE2
  it('get sliced padded address', async () => {

    const result = await target.getSlicedPaddedAddress({ enableCcipRead: true });

    expect(result).to.equal(
      "0x746f6d"
    );

  });

  //DONE2
  it('memory arrays', async () => {

    const result = await target.memoryArrays(["0x00"], { enableCcipRead: true });
  });

  //DONE2
  it('get two static values from two different targets', async () => {

    //try {

      const result = await target.getLatestFromTwo(l2ContractAddress!, { enableCcipRead: true });

      console.log("result", result);
      const decodedResult = AbiCoder.defaultAbiCoder().decode(['uint256'], result[0][0]);
      const decodedResultTwo = AbiCoder.defaultAbiCoder().decode(['uint256'], result[1][0]);


      
      expect(decodedResult[0]).to.equal(
        49n
      );

      expect(decodedResultTwo[0]).to.equal(
        42n
      );

    //  } catch (e) {
        
        //console.log(e);
        //const iface = new ethers.Interface(["error Problem(bytes)"]);
        //const erro = iface.decodeErrorResult("Problem", e.data)
    
        //console.log(erro);
    
        //parsedValue = Result(1) [ '0x2a' ]; - fails

        //ans -   '0x000000000000000000000000000000000000000000000000000000000000002a' - succeeds
        //alt - Result(1) [ '0x2a' ] - fails
      //}

  });

  //DONE2
  it.only('returns a string from a storage slot on a target', async () => {

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

  //DONE2
  it('get an address by slicing part of a previously fetched value', async () => {

    const bl = ethers.getBytes("0xab");

    console.log("BL", bl[0]);

    //try {
    const result = await target.getAddressFromRefSlice({ enableCcipRead: true });
    expect(result).to.equal('tom');
  
    //} catch (e) {
    //  console.log(e);
    //  const iface = new ethers.Interface(["error Problem(bytes)"]);
    //  const erro = iface.decodeErrorResult("Problem", e.data)
  
    //  console.log(erro);
  
      //ans -   '0x000000000000000000000000000000000000000000000000000000000000002a' - succeeds
      //alt - Result(1) [ '0x2a' ] - fails
    //}
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
});
