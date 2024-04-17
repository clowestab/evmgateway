import type { HandlerDescription } from '@chainlink/ccip-read-server';
import type { Fragment, Interface, JsonFragment } from '@ethersproject/abi';
import {
  concat,
  dataSlice,
  getBytes,
  solidityPackedKeccak256,
  toBigInt,
  zeroPadValue,
  hexlify
} from 'ethers';

import type { IProofService, ProvableBlock } from './IProofService.js';
import { AbiCoder } from 'ethers';

const OP_CONSTANT = 0x00;
const OP_BACKREF = 0x20;
const OP_SLICE = 0x40;
//const OP_SETADDR = 0x60;

export enum StorageLayout {
  /**
   * address,uint,bytes32,bool
   */
  FIXED,
  /**
   * array,bytes,string
   */
  DYNAMIC,
}

interface StorageElement {
  slots: bigint[];
  value: () => Promise<string>;
  isDynamic: boolean;
}

interface Server {
  add: (
    abi: string | readonly (string | Fragment | JsonFragment)[] | Interface,
    handlers: HandlerDescription[]
  ) => void;
}

function memoize<T>(fn: () => Promise<T>): () => Promise<T> {
  let promise: Promise<T> | undefined;
  return () => {
    if (!promise) {
      promise = fn();
    }
    return promise;
  };
}

export class EVMGateway<T extends ProvableBlock> {
  readonly proofService: IProofService<T>;

  constructor(proofService: IProofService<T>) {
    this.proofService = proofService;
  }

  add(server: Server) {
    const abi = [
      /**
       * This function implements a simple VM for fetching proofs for EVM contract storage data.
       * Programs consist of an array of `commands` and an array of `constants`. Each `command` is a
       * short program that computes the slot number of a single EVM storage value. The gateway then
       * returns a proof of a value at that slot number. Commands can also specify that the value is
       * dynamic-length, in which case the gateway may return proofs for multiple slots in order for
       * the caller to be able to reconstruct the entire value.
       *
       * Each command is a 32 byte value consisting of a single target byte, a single flags byte, followed by 30 instruction
       * bytes. 
       * 
       * Valid targets are:
       * - any decimal number that can fit into a single byte (max 255)
       * 
       * Valid flags are:
       *  - 0x01 - If set, the value to be returned is dynamic length.
       *
       * The VM implements a very simple stack machine, and instructions specify operations that happen on
       * the stack. In addition, the VM has access to the result of previous commands, referred to here
       * as `values`.
       *
       * The most significant 3 bits of each instruction byte are the opcode, and the least significant
       * 5 bits are the operand. The following opcodes are defined:
       *  - 0x00 - `push(constants[operand])`
       *  - 0x20 - `push(values[operand])`
       *  - 0x40 - `slice20(16, 20)` - 
       *  - 0x60 - `setaddr()` - pops the top stack element and uses it as the address for subsequent fetches
       *  - 0x70 - `halt` - do not process any further instructions for this command.
       *
       * After a `halt` is reached or the end of the command word is reached, the elements on the stack
       * are hashed recursively, starting with the first element pushed, using a process equivalent
       * to the following:
       *   def hashStack(stack):
       *     right = stack.pop()
       *     if(stack.empty()):
       *       return right
       *     return keccak256(concat(hashStack(stack), right))
       *
       * The final result of this hashing operation is used as the base slot number for the storage
       * lookup. This mirrors Solidity's recursive hashing operation for determining storage slot locations.
       */
      'function getStorageSlots(bytes32[] memory commands, bytes[] memory constants) external view returns(bytes[] memory witnesses)',
    ];
    server.add(abi, [
      {
        type: 'getStorageSlots',
        func: async (args) => {
          try {
            const [commands, constants] = args;

            //Returns a hexadecimal encoded bytes[] of concatanated proofs
            const concatanatedProofs = await this.createProofs(commands, constants);

            //console.log("concatanatedProofs", concatanatedProofs);

            //Handler wants an array of promises
            //return an array of proofs which the ccip-read-server will encode as the return type from the abi (bytes[])
            return [concatanatedProofs];

            // eslint-disable-next-line @typescript-eslint/no-explicit-any
          } catch (e: any) {
            console.log(e.stack);
            throw e;
          }
        },
      },
    ]);
    return server;
  }

  /**
   *
   * @param address The address to fetch storage slot proofs for
   * @param paths Each element of this array specifies a Solidity-style path derivation for a storage slot ID.
   *              See README.md for details of the encoding.
   */
  async createProofs(
    commands: string[],
    constants: string[]
  ): Promise<string[]> {

    
    const block = await this.proofService.getProvableBlock();

    console.log("WTF", block);

    const allRequests: Promise<StorageElement>[] = [];
    const requestsMap: {[key: string]: Promise<StorageElement>[]} = {};
    // For each request, spawn a promise to compute the set of slots required
    for (let i = 0; i < commands.length; i++) {

      const command = commands[i];
      const commandWord = getBytes(command);
      const targetIndex = commandWord[0];

      /*
      console.log("targetIndex", targetIndex);
      console.log("targets", targets);
      const target = targets[targetIndex];


      console.log("target111", target);

      //00000001
      //const hasStaticTarget = (targetFlag & 0xFF) != 0;
      var targetToUse = target;

      const targetAsInt = BigInt(target);

      console.log("target222", targetAsInt);

      if (targetAsInt < 256) {

        console.log("loool", allRequests.length);

        targetToUse = await (await allRequests[parseInt(targetAsInt.toString())]).value();

        console.log("TTU", targetToUse);

        //TODO tom decode the address here 
        targetToUse = AbiCoder.defaultAbiCoder().decode(['address'], targetToUse)[0];

        console.log("targetToUYse");
        console.log(targetToUse);
      }
*/



      const [newRequest, target] = await this.getValueFromPath(
        block,
        command,
        constants,
        allRequests.slice()
      );

      !(target in requestsMap) && (requestsMap[target] = [])

      requestsMap[target].push(
        newRequest
      );

      allRequests.push(newRequest);
    }

    console.log("here1");

    const resolvedTargets = Object.keys(requestsMap);

    console.log("resolvedTargets", resolvedTargets);

    const proofArray = resolvedTargets.map(async (targetAddress) => {
      // Resolve all the outstanding requests
      const results = await Promise.all(requestsMap[targetAddress]);
      const slots = Array.prototype.concat(
        ...results.map((result) => result.slots)
      );
      return this.proofService.getProofs(block, targetAddress, slots);
    });

    /*
    //Proof service returns 

            return AbiCoder.defaultAbiCoder().encode([
            'tuple(uint256 blockNo, bytes blockHeader)',
            'tuple(bytes[] stateTrieWitness, bytes[][] storageProofs)',
        ], [{ blockNo, blockHeader }, proof]);

    */

    const res = await Promise.all(proofArray);
    console.log("lil", res);

    return res;

    /*const resA = AbiCoder.defaultAbiCoder().encode(
      [
        'bytes[]',
      ],
      [res]
    );

    console.log("lilA", resA);

    return resA;*/
    
    //console.log("proofArray", proofArray);

    //return proofArray;
  }

  private async executeOperation(
    operation: number,
    constants: string[],
    requests: Promise<StorageElement>[]
  ): Promise<string> {
    const opcode = operation & 0xe0;
    const operand = operation & 0x1f;

    console.log("OPERAND", operand);

    switch (opcode) {
      case OP_CONSTANT:
        return constants[operand];
      case OP_BACKREF:
        const backref = await (await requests[operand]).value();

        console.log("backref", backref);

        return backref;

      //Returns sliced data from the previous requests value and uses it as an index
      case OP_SLICE:

      console.log("operandconst", constants[operand]);
      
        const [offset, length] = getBytes(constants[operand])

        console.log(requests);

        const value = await (await requests[requests.length - 1]).value();

        console.log("vallllu", value);

        const parsedValue = hexlify(getBytes(value).slice(offset, offset + length));

        //console.log("PARSED", parsedValue);

        const paddedParsed = zeroPadValue(parsedValue, 32);

        console.log("paddedParsed", paddedParsed);

        return paddedParsed;

      default:
        throw new Error('Unrecognized opcodse ' + opcode);
    }
  }

  private async computeFirstSlot(
    command: string,
    constants: string[],
    requests: Promise<StorageElement>[]
  ): Promise<{ slot: bigint; isDynamic: boolean }> {
    const commandWord = getBytes(command);
    const flags = commandWord[1];
    const isDynamic = (flags & 0x01) != 0;

    let slot = toBigInt(
      await this.executeOperation(commandWord[2], constants, requests)
    );

    console.log("COM", command);

    // If there are multiple path elements, recursively hash them solidity-style to get the final slot.
    for (let j = 3; j < 32 && commandWord[j] != 0xff; j++) {

      console.log("More path", commandWord[j]);

      const index = await this.executeOperation(
        commandWord[j],
        constants,
        requests
      );
      slot = toBigInt(
        solidityPackedKeccak256(['bytes', 'uint256'], [index, slot])
      );
    }

    console.log("SLOTs", slot);

    return { slot, isDynamic };
  }

  private async getDynamicValue(
    block: T,
    address: string,
    slot: bigint
  ): Promise<StorageElement> {
    const firstValue = getBytes(
      await this.proofService.getStorageAt(block, address, slot)
    );
    // Decode Solidity dynamic value encoding
    if (firstValue[31] & 0x01) {
      // Long value: first slot is `length * 2 + 1`, following slots are data.
      const len = (Number(toBigInt(firstValue)) - 1) / 2;
      const hashedSlot = toBigInt(solidityPackedKeccak256(['uint256'], [slot]));
      const slotNumbers = Array(Math.ceil(len / 32))
        .fill(BigInt(hashedSlot))
        .map((i, idx) => i + BigInt(idx));
      return {
        slots: Array.prototype.concat([slot], slotNumbers),
        isDynamic: true,
        value: memoize(async () => {
          const values = await Promise.all(
            slotNumbers.map((slot) =>
              this.proofService.getStorageAt(block, address, slot)
            )
          );
          return dataSlice(concat(values), 0, len);
        }),
      };
    } else {
      // Short value: least significant byte is `length * 2`, other bytes are data.
      const len = firstValue[31] / 2;
      return {
        slots: [slot],
        isDynamic: true,
        value: () => Promise.resolve(dataSlice(firstValue, 0, len)),
      };
    }
  }

  private async getValueFromPath(
    block: T,
    command: string,
    constants: string[],
    requests: Promise<StorageElement>[]
  ): Promise<[Promise<StorageElement>, string]> {

    const commandWord = getBytes(command);
    const targetData = commandWord[0];

    const tType = targetData & 0xe0;
    const tOperand = targetData & 0x1f; //00011111

    const { slot, isDynamic } = await this.computeFirstSlot(
      command,
      constants,
      requests
    );
    
    const target = constants[tOperand];

    var storageElement: Promise<StorageElement>;

    if (!isDynamic) {
      storageElement = Promise.resolve({
        slots: [slot],
        isDynamic,
        value: memoize(async () => {

          const storageValue = await this.proofService.getStorageAt(block, target, slot);

          console.log("storageValue", storageValue);
          
          return zeroPadValue(
            storageValue,
            32
          )
        }
        ),
      });
    } else {
      storageElement = this.getDynamicValue(block, target, slot);
    }

    return [storageElement, target];
  }
}
