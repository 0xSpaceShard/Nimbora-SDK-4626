# Fast Withdrawal

The main goal for phase two of the One Transaction Withdrawal is to enable users to move their assets from Starknet to the Ethereum network as fast as possible, effortlessly.This project consists of two main components: L1 and L2.

![Fw](public/fw_logic.png)


## L1 

The L1 component, developed using the Hardhat framework, contains Ethereum smart contracts that facilitate the fast withdrawal logic. 

### Contracts

**FWERC20**: contracts inheriting from ERC4626 yield bearing token standard allowing Liquidity providers to earn fees when their assets are used to transfer bridger assets. LPs are whitelisted and they are refunded through peridic batch based on time and amount.

**FWETH**: contract inheriting from FWERC20 in order to work with ETH.

**FWETH**: contract inheriting from FWERC20 in order to work with ETH.

**MulticallPayableWithGasLimit**: multicall that allow to set a gas limit and to send eth. Useful to handle multicall of handleBridgeTokens (from FW)


#### Install Dependencies

```sh
yarn
```

#### Compile

```sh
yarn hardhat compile
```

#### Test

```sh
yarn hardhat test
```

#### Scripts

Create a .env file providing a private key and an infura key (as shown in the .env.exemple) 
Fill the scripts/config.ts the right address, like L2FW, weth, btc....
Now deploy a FWERC20, FWETH and the multicall with the following command

```sh
yarn hardhat deploy 
```

Prepare deployed FW by running prepareFW (add initial liq + register multicall as allowed caller)

```sh
yarn hardhat run scripts/prepareFW.ts
```


## L2

The L2 component, is in cairo 1, using the latest syntax. It is using the scarb build toolchain and package manager. 

### Contracts

**fw**: this contract allow users to deposit any registered tokens in order to receive the corresponding amount (minus LP fees + ETH gas fees ) on their L1 address. They can also get refunded if the tx hasn't been processed. Liquidity accumulated can be permisionlessely rebalanced under certain condtions.


#### Compile

```sh
scarb build
```

#### Test

```sh
scarb test
```

#### Scripts

Add your account address, private key and the desired network url (as shown in the .env.exemple). Head to scripts folder.

**declareContracts**: 

```sh
npx ts-node declareContracts.ts
```
**deployContracts**: 

```sh
npx ts-node deployContracts.ts
```

**registerToken**: 

Add the necessary data:
add the token address to the .env
- the StarkGate bridge address associated to the token
- the L1FW address associated to the token
- parameters for the token such as limit

```sh
npx ts-node registerToken.ts
```