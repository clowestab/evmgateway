import { EVMGateway } from '@ensdomains/evm-gateway';
import { JsonRpcProvider } from 'ethers';
import { ArbProofService, type ArbProvableBlock } from './ArbProofService.js';
import { InMemoryBlockCache } from './blockCache/InMemoryBlockCache.js';

export type ArbGateway = EVMGateway<ArbProvableBlock>;

export async function makeArbGateway(
  l1Provider: JsonRpcProvider,
  l2Provider: JsonRpcProvider,
  l2RollupAddress: string
): Promise<ArbGateway> {
  return new EVMGateway(
    new ArbProofService(
      l1Provider,
      l2Provider,
      l2RollupAddress,
      new InMemoryBlockCache()
    )
  );
}

export { ArbProofService, type ArbProvableBlock };
