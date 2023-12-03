
import btc from "../deployments/goerli/ERC20Mintable_btc.json"
import btc_bridge from "../deployments/goerli/StarkGate_btc.json"
import usdc from "../deployments/goerli/ERC20Mintable_USDC.json"
import usdc_bridge from "../deployments/goerli/StarkGate_USDC.json"
import usdt from "../deployments/goerli/ERC20Mintable_USDT.json"
import usdt_bridge from "../deployments/goerli/StarkGate_USDT.json"
import { ethers } from "hardhat"


const tokenList = [
    {
        erc20_address: btc.address,
        l1_bridge_address: btc_bridge.address,
        decimals: 8,
        erc20_tag: 'btc',
        inital_bridge_liquidity: (BigInt(10) ** BigInt(8)) * BigInt(100000) // 10^5 btc
    },
    {
        erc20_address: usdc.address,
        l1_bridge_address: usdc_bridge.address,
        decimals: 6,
        erc20_tag: 'USDC',
        inital_bridge_liquidity: (BigInt(10) ** BigInt(6)) * BigInt(100000) // 10^5 usdc
    },
    {
        erc20_address: usdt.address,
        l1_bridge_address: usdt_bridge.address,
        decimals: 6,
        erc20_tag: 'USDT',
        inital_bridge_liquidity: (BigInt(10) ** BigInt(6)) * BigInt(100000) // 10^5 usdt
    }
]


async function main() {
    const [deployer] = await ethers.getSigners();
    const balance0ETH = await ethers.provider.getBalance(deployer.address);
    console.log("user address", deployer.address)
    console.log("user balance", ethers.formatUnits(balance0ETH, 18))

    for (let index = 0; index < tokenList.length; index++) {
        const element = tokenList[index];
        const erc20 = await ethers.getContractAt("ERC20Mintable", element.erc20_address)
        await erc20.transfer(element.l1_bridge_address, element.inital_bridge_liquidity)
        console.log(`ERC20 ${element.erc20_tag} Send to the L1 mock bridge ${element.l1_bridge_address}`)
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
