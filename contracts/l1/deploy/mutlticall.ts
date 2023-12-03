import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deployer } = await getNamedAccounts();
    const { deploy } = deployments;
    const MutlticallDeployment = await deploy(`Multicall2`, {
        from: deployer,
        log: true,
        contract: 'Multicall2',
        args: [],
    });
    console.log(`Multical contract deployed to ${MutlticallDeployment.address}`);
}
export default func;
func.tags = ['MulticallOwnable'];

