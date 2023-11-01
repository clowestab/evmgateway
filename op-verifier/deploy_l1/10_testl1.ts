import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;

  const {deployer} = await getNamedAccounts();

  const OPVerifier = await deployments.get('OPVerifier');
  const L2PublicResolver = await hre.companionNetworks['l2'].deployments.get('L2PublicResolver');

  await deploy('TestL1', {
    from: deployer,
    args: [OPVerifier.address, L2PublicResolver.address],
    log: true,
  });
};
export default func;
func.tags = ['TestL1'];
