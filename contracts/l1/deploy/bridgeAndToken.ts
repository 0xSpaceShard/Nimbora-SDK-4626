import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { networkAddresses } from '../scripts/config';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deployer } = await getNamedAccounts();
    const { deploy } = deployments;
    const network: string = hre.network.name;
    const addresses = network == 'mainnet' ? networkAddresses['mainnet'] : networkAddresses['goerli'];

    console.log('stat')
    const tokenList = [
        {
            name: "bitcoin",
            symbol: "btc",
            decimals: 8,
            l2_bridge: "0x71737b17937097633c567b43f8109389ae94d10d46af6c7710e17de944f6720"
        },
        {
            name: "USD Coin",
            symbol: "USDC",
            decimals: 6,
            l2_bridge: "0x27df81fd3a07e38eb012a691c054284e950cf15ca9fff0e36a7059831425d67"
        },
        {
            name: "Tether USD",
            symbol: "USDT",
            decimals: 6,
            l2_bridge: "0x6bcb34f71ffcf456143fe38f98612e625438402f7e3bab4bb9db4c77fca1354"
        }
    ]

    for (let index = 0; index < tokenList.length; index++) {
        const element = tokenList[index];
        const erc20Deployment = await deploy(`ERC20Mintable_${element.symbol}`, {
            from: deployer,
            log: true,
            contract: 'ERC20Mintable',
            args: [
                element.name, element.symbol, element.decimals, BigInt(10) ** BigInt(18) * BigInt(100000000)
            ],
        });
        console.log(`ERC20Mintable ${element.symbol} contract deployed at ${erc20Deployment.address}`);

        const bridgeDeployment = await deploy(`StarkGate_${element.symbol}`, {
            from: deployer,
            log: true,
            contract: 'StarkGateGoerli',
            args: [
                erc20Deployment.address, addresses.starknetCore, element.l2_bridge
            ],
        });
        console.log(`StarkGate ${element.symbol} contract deployed at ${bridgeDeployment.address}`);
    }
};

export default func;
func.tags = ['bridgeAndToken'];
