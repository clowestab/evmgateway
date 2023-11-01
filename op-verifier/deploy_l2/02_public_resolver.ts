import { ethers }                    from 'hardhat'
import { DeployFunction }            from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {

    console.log("here");
    
    const { getNamedAccounts, deployments } = hre
    const { deploy, get }                   = deployments
    const { deployer }                      = await getNamedAccounts()

    let deployArguments = [];

    const deployTx = await deploy('L2PublicResolver', {
        from: deployer,
        args: deployArguments,
        log:  true,
    })

    if (deployTx.newlyDeployed) {

        console.log(`L2 Public Resolver deployed at  ${deployTx.address}`);

        console.log("Verifying on Etherscan..");

        await hre.run("verify:verify", {
          address: deployTx.address,
          constructorArguments: deployArguments,
        });
    }
}

func.tags         = ['resolver', 'l2']
func.dependencies = []

export default func
