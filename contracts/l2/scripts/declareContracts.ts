import { Account, RpcProvider, constants, json } from 'starknet';
import fs from 'fs';
import dotenv from 'dotenv';

dotenv.config({ path: __dirname + '/../.env' });
const provider = new RpcProvider({ nodeUrl: constants.NetworkName.SN_GOERLI })
const owner = new Account(provider, process.env.ACCOUNT_ADDRESS as string, process.env.ACCOUNT_PK as string, '1'); // 1 if upgraded argent account


export async function declareGasOracle() {
    const compiledContractClass = await json.parse(fs.readFileSync(`../target/dev/pooling4626_GasOracle.compiled_contract_class.json`).toString('ascii'));
    const declareResponse = await owner.declare({
        contract: compiledContractClass,
    });
    console.log("declared")
    await provider.waitForTransaction(declareResponse.transaction_hash);
    console.log("declared confirmed")
    console.log('Gas Oracle classHash: ', declareResponse.class_hash);
    fs.appendFile(__dirname + '/../.env', `\nGAS_ORACLE_CLASS_HASH=${declareResponse.class_hash}`, function (err) {
        if (err) throw err;
    });
}

export async function declareMockStarkgate() {
    const compiledContractClass = await json.parse(fs.readFileSync(`../target/dev/pooling4626_TokenBridge.compiled_contract_class.json`).toString('ascii'));
    const declareResponse = await owner.declare({
        contract: compiledContractClass,
    });
    console.log("declared")
    await provider.waitForTransaction(declareResponse.transaction_hash);
    console.log("declared confirmed")
    console.log('mockStarkgate classHash: ', declareResponse.class_hash);
    fs.appendFile(__dirname + '/../.env', `\nSTARKGATE_CLASS_HASH=${declareResponse.class_hash}`, function (err) {
        if (err) throw err;
    });
}

export async function declareMockErc20() {
    const compiledContractClass = await json.parse(fs.readFileSync(`../target/dev/pooling4626_TokenMock.compiled_contract_class.json`).toString('ascii'));
    const declareResponse = await owner.declare({
        contract: compiledContractClass
    });
    console.log("declared")
    await provider.waitForTransaction(declareResponse.transaction_hash);
    console.log("declared confirmed")
    console.log('ERC20 starkgate token classHash: ', declareResponse.class_hash);
    fs.appendFile(__dirname + '/../.env', `\nERC20_STARKGATE_CLASS_HASH=${declareResponse.class_hash}`, function (err) {
        if (err) throw err;
    });
}

export async function declarePooling4626() {
    const compiledContractClass = await json.parse(fs.readFileSync(`../target/dev/fw_Fw.sierra.json`).toString('ascii'));
    const declareResponse = await owner.declare({
        contract: compiledContractClass
    });
    await provider.waitForTransaction(declareResponse.transaction_hash);
    console.log("declared")
    console.log('Pooling4626 classHash: ', declareResponse.class_hash);
    fs.appendFile(__dirname + '/../.env', `\nPOOLING4626_CLASS_HASH=${declareResponse.class_hash}`, function (err) {
        if (err) throw err;
    });
}

async function main() {
    await declareGasOracle();
    await declareMockStarkgate();
    await declareMockErc20();
    await declarePooling4626();
}

main();



