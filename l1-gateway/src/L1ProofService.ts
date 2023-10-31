import {
  AbiCoder,
  encodeRlp as encodeRlp_,
  type AddressLike,
  type JsonRpcProvider,
  //isBytesLike,
  hexlify,
  //type BytesLike,
} from 'ethers';

import { keccak256 } from "@ethersproject/keccak256";

import { EVMProofHelper, type IProofService } from '../../evm-gateway';
import { Block, BlockHeader, type JsonRpcBlock } from '@ethereumjs/block';
const { rlp } = require('ethereumjs-util');


type RlpObject = Uint8Array | Array<RlpObject>;
const encodeRlp = encodeRlp_ as (object: RlpObject) => string;

export type L1ProvableBlock = number;

/**
 * The proofService class can be used to calculate proofs for a given target and slot on the Optimism Bedrock network.
 * It's also capable of proofing long types such as mappings or string by using all included slots in the proof.
 *
 */
export class L1ProofService implements IProofService<L1ProvableBlock> {
  private readonly provider: JsonRpcProvider;
  private readonly helper: EVMProofHelper;

  constructor(provider: JsonRpcProvider) {
    this.provider = provider;
    this.helper = new EVMProofHelper(provider);
  }

  /**
   * @dev Returns an object representing a block whose state can be proven on L1.
   */
  async getProvableBlock(): Promise<number> {
    const block = await this.provider.getBlock('latest');
    if (!block) throw new Error('No block found');
    return block.number - 1;
  }

  /**
   * @dev Returns the value of a contract state slot at the specified block
   * @param block A `ProvableBlock` returned by `getProvableBlock`.
   * @param address The address of the contract to fetch data from.
   * @param slot The slot to fetch.
   * @returns The value in `slot` of `address` at block `block`
   */
  getStorageAt(
    block: L1ProvableBlock,
    address: AddressLike,
    slot: bigint
  ): Promise<string> {
    return this.helper.getStorageAt(block, address, slot);
  }

  /**
   * @dev Fetches a set of proofs for the requested state slots.
   * @param block A `ProvableBlock` returned by `getProvableBlock`.
   * @param address The address of the contract to fetch data from.
   * @param slots An array of slots to fetch data for.
   * @returns A proof of the given slots, encoded in a manner that this service's
   *   corresponding decoding library will understand.
   */
  async getProofs(
    blockNo: L1ProvableBlock,
    address: AddressLike,
    slots: bigint[]
  ): Promise<string> {
    const proof = await this.helper.getProofs(blockNo, address, slots);

    console.log("proooof", proof);

    const rpcBlock: JsonRpcBlock = await this.provider.send(
      'eth_getBlockByNumber',
      ['0x' + blockNo.toString(16), false]
    );

    //gives correct hash 0x9b25c5f9eb9be023e44cb2b0c133b0027dd77ec31b6ba8be642d587a1374f218

    console.log("BLOCK NUM", blockNo);
    console.log("BLOCK rpcBlock", rpcBlock); //has correct hash

    const blockHeader2 = [
        rpcBlock.parentHash,
        rpcBlock.sha3Uncles,
        rpcBlock.miner,
        rpcBlock.stateRoot,
        rpcBlock.transactionsRoot,
        rpcBlock.receiptsRoot,
        rpcBlock.logsBloom,
        "0x",
        rpcBlock.number,
        rpcBlock.gasLimit,
        rpcBlock.gasUsed,
        rpcBlock.timestamp,
        rpcBlock.extraData,
        rpcBlock.mixHash,
        rpcBlock.nonce,
        rpcBlock.baseFeePerGas!
    ];

    console.log("here 1", blockHeader2);
    const encodedBlockHeader = rlp.encode(blockHeader2);
    const encodedBlockHeaderString = ("0x" + encodedBlockHeader.toString('hex'));
    //var arrByte = Uint8Array.from(encodedBlockHeader);

    //const blockHash = keccak256(encodedBlockHeader);

    console.log("here 2", encodedBlockHeaderString);

    const bh = new BlockHeader(rpcBlock);

let bhhex = encodeRlp(bh.raw());

    console.log("here 2bh", bhhex);

const hexI = Uint8Array.from(Buffer.from(encodedBlockHeaderString, 'hex'));


    const block = Block.fromRPC(rpcBlock);
    const blockHeader = encodeRlp(hexI);
    const blockHs = keccak256(blockHeader);


        console.log("here 3", blockHeader);
        console.log("here 4", blockHs);


        console.log("comp1", bh);
        console.log("comp2", bh);

        console.log("type1", block.header.raw());

        const k1 = keccak256(encodedBlockHeaderString);
        const k2 = keccak256(blockHeader);

        console.log("k1", k1);
        console.log("k2", k2);


const hex = hexlify(encodedBlockHeaderString);//Uint8Array.from(Buffer.from(encodedBlockHeaderString, 'hex'));

    return AbiCoder.defaultAbiCoder().encode(
      [
        'tuple(uint256 blockNo, bytes blockHeader)',
        'tuple(bytes[] stateTrieWitness, bytes[][] storageProofs)',
      ],
      [[ blockNo, hex ], proof]
    );

    //returns 5
    //returns 0xf9021ea.. for blockHeader
    //keccak256 of that gives 0x61d5f17c068369c28be1de5af3e06091fac39fe5d223f7ea49539ed0e37acd71
  }
}
