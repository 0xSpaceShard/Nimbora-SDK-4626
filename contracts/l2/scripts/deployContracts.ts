import { Account, constants, RpcProvider } from "starknet";
import fs from 'fs';
import dotenv from 'dotenv';

dotenv.config({ path: __dirname + '/../.env' });
const provider = new RpcProvider({ nodeUrl: constants.NetworkName.SN_GOERLI })
const owner = new Account(provider, process.env.ACCOUNT_ADDRESS as string, process.env.ACCOUNT_PK as string, '1'); // 1 if upgraded argent account

const selector_l1_gas_price = "0x02b36f46b7114008b5cacc0021e919d4303c396beea93c03111312b4a273388f";
const eth = "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7";

async function deployGasOracle(): Promise<string> {
    let contractAddress: any;
    let { transaction_hash, contract_address } = await owner.deploy({
        classHash: process.env.GAS_ORACLE_CLASS_HASH as string,
        constructorCalldata: {
            owner: owner.address,
            relayer: owner.address
        },
    });
    [contractAddress] = contract_address;
    await provider.waitForTransaction(transaction_hash);
    console.log('Gas Oracle Deployed At', contractAddress);
    fs.appendFile(__dirname + '/../.env', `\nGAS_ORACLE_CONTRACT_ADDRESS=${contractAddress}`, function (err) {
        if (err) throw err;
    });
    return (contractAddress)
}

async function deployToken(): Promise<string> {
    let contractAddress: any;
    let { transaction_hash, contract_address } = await owner.deploy({
        classHash: process.env.ERC20_STARKGATE_CLASS_HASH as string,
        constructorCalldata: {
            initial_supply_low: (10 ** 5) * 10 ** 18,
            initial_supply_high: 0,
            recipient: owner.address,
        },
    });

    [contractAddress] = contract_address;
    await provider.waitForTransaction(transaction_hash);
    console.log(`✅ ERC20 Starkgate Token  contract deployed to `, contractAddress);
    fs.appendFile(__dirname + '/../.env', `\nERC20_STARKGATE_CONTRACT_ADDRESS=${contractAddress}`, function (err) {
        if (err) throw err;
    });
    return (contractAddress)
}

async function deployBridge(): Promise<string> {
    let contractAddress: any;
    let { transaction_hash, contract_address } = await owner.deploy({
        classHash: process.env.STARKGATE_CLASS_HASH as string,
        constructorCalldata: {
            l2_address: process.env.ERC20_STARKGATE_CONTRACT_ADDRESS == undefined ?? "",
            l1_bridge: "",
        },
    });
    [contractAddress] = contract_address;
    await provider.waitForTransaction(transaction_hash);
    console.log(`✅ ERC20 Starkgate Bridge contract deployed to `, contractAddress);
    fs.appendFile(__dirname + '/../.env', `\nSTARKGATE_CONTRACT_ADDRESS=${contractAddress}`, function (err) {
        if (err) throw err;
    });
    return (contractAddress)
}

async function deployPooling4626(): Promise<string> {
    let contractAddress: any;
    console.log("deploy Pooling4626")

    const calldata = {
        owner: owner.address,
        gas_token: eth,
        fees_collector: "",
        gas_oracle: process.env.GAS_ORACLE_CONTRACT_ADDRESS ?? "",
        gas_oracle_selector: selector_l1_gas_price,
        gas_required_low: "",
        gas_required_high: "",
        participant_required_low: "",
        participant_required_high: "",
        underlying_bridge: "",
        yield_bridge: "",
        deposit_limit_low_low: "",
        deposit_limit_low_high: "",
        deposit_limit_high_low: "",
        deposit_limit_high_high: "",
    }

    let { transaction_hash, contract_address } = await owner.deploy({
        classHash: process.env.POOLING4626_CLASS_HASH as string,
        constructorCalldata: calldata,
    });

    [contractAddress] = contract_address;
    await provider.waitForTransaction(transaction_hash);
    console.log('✅ Pooling4626 contract deployed to ', contractAddress);
    fs.appendFile(__dirname + '/../.env', `\nPOOLING4626_CONTRACT_ADDRESS=${contractAddress}`, function (err) {
        if (err) throw err;
    });
    return (contractAddress)
}

async function deployContracts() {
    await deployGasOracle();
    await deployToken();
    await deployBridge();
    await deployPooling4626();
}
deployContracts();
