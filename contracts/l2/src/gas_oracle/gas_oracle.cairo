#[starknet::contract]
mod GasOracle {
    use starknet::{
        get_caller_address, get_block_info, SyscallResult, StorageBaseAddress,
        contract_address::{ContractAddress, ContractAddressZeroable}, storage_access::Store,
    };
    use box::BoxTrait;
    use pooling4626::gas_oracle::interface::IGasOracle;
    use openzeppelin::access::ownable::{OwnableComponent};
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        /// Relayer address that can set_l1_gas_price
        relayer: ContractAddress,
        /// Current l1 gas price 
        l1_gas_price: u256,
        /// Last time l1 gas price has been updated
        last_update: u64,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        RelayerSet: RelayerSet,
        L1GasPriceSet: L1GasPriceSet
    }

    #[derive(Drop, starknet::Event)]
    struct RelayerSet {
        relayer: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct L1GasPriceSet {
        gas_price: u256,
        last_update: u64
    }

    mod Errors {
        const NOT_RELAYER: felt252 = 'Caller is not the relayer';
        const ZERO_ADDRESS_CALLER: felt252 = 'Caller is the zero address';
        const ZERO_ADDRESS_RELAYER: felt252 = 'Relayer is the zero address';
        const ZERO_AMOUNT_GAS : felt252 = 'Zero amount for gas';
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, relayer: ContractAddress ) {
        self.ownable.initializer(owner);
        self._set_relayer(relayer);
    }

    #[external(v0)]
    impl GasOracle of IGasOracle<ContractState> {

        fn relayer(self: @ContractState) -> ContractAddress {
            self.relayer.read()
        }

        fn l1_gas_price(self: @ContractState) -> u256 {
            self.l1_gas_price.read()
        }

        fn last_update(self: @ContractState) -> u64 {
            self.last_update.read()
        }

        fn set_relayer(ref self: ContractState, new_relayer: ContractAddress) {
            self.ownable.assert_only_owner();
            self._set_relayer(new_relayer);
            self.emit(RelayerSet { relayer: new_relayer });
        }
    
        fn set_l1_gas_price(ref self: ContractState, gas_price: u256) {
            self.assert_only_relayer();
            assert(gas_price != 0, Errors::ZERO_AMOUNT_GAS);
            let info = get_block_info().unbox();
            self.l1_gas_price.write(gas_price);
            self.last_update.write(info.block_timestamp);
            self.emit(L1GasPriceSet{gas_price:gas_price, last_update: info.block_timestamp});
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        
        fn assert_only_relayer(self: @ContractState) {
            let relayer: ContractAddress = self.relayer.read();
            let caller: ContractAddress = get_caller_address();
            assert(!caller.is_zero(), Errors::ZERO_ADDRESS_CALLER);
            assert(caller == relayer, Errors::NOT_RELAYER);
        }

        fn _set_relayer(
            ref self: ContractState, new_relayer: ContractAddress
        ) {
            assert(!new_relayer.is_zero(), Errors::ZERO_ADDRESS_RELAYER);
            self.relayer.write(new_relayer);
        }

    }
}
