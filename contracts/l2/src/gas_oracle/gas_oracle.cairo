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
        const ZERO_AMOUNT_GAS: felt252 = 'Zero amount for gas';
    }

    /// @notice Initializes the contract with specified owner and relayer addresses.
    /// @dev This constructor function sets the initial owner and relayer of the contract.
    /// @param owner The address to be set as the initial owner of the contract.
    /// @param relayer The address to be set as the initial relayer of the contract.
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, relayer: ContractAddress) {
        self.ownable.initializer(owner);
        self._set_relayer(relayer);
    }

    #[external(v0)]
    impl GasOracle of IGasOracle<ContractState> {
        /// @notice Retrieves the current relayer's address.
        /// @return ContractAddress The address of the current relayer.
        fn relayer(self: @ContractState) -> ContractAddress {
            self.relayer.read()
        }

        /// @notice Retrieves the current L1 gas price.
        /// @return u256 The current L1 gas price.
        fn l1_gas_price(self: @ContractState) -> u256 {
            self.l1_gas_price.read()
        }

        /// @notice Retrieves the timestamp of the last update.
        /// @return u64 The timestamp of the last update.
        fn last_update(self: @ContractState) -> u64 {
            self.last_update.read()
        }

        /// @notice Sets a new relayer for the contract.
        /// @dev This function can only be called by the contract owner.
        /// @param new_relayer The address of the new relayer.
        /// @notice Emits a RelayerSet event after successfully setting the new relayer.
        fn set_relayer(ref self: ContractState, new_relayer: ContractAddress) {
            self.ownable.assert_only_owner();
            self._set_relayer(new_relayer);
            self.emit(RelayerSet { relayer: new_relayer });
        }

        /// @notice Sets a new L1 gas price for the contract.
        /// @dev This function can only be called by the current relayer.
        /// @param gas_price The new gas price to be set.
        /// @notice Emits an L1GasPriceSet event after successfully setting the new gas price.
        fn set_l1_gas_price(ref self: ContractState, gas_price: u256) {
            self.assert_only_relayer();
            assert(gas_price != 0, Errors::ZERO_AMOUNT_GAS);
            let info = get_block_info().unbox();
            self.l1_gas_price.write(gas_price);
            self.last_update.write(info.block_timestamp);
            self.emit(L1GasPriceSet { gas_price: gas_price, last_update: info.block_timestamp });
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        /// @notice Asserts that the caller of the function is the designated relayer.
        /// @dev Throws an error if the caller is not the relayer or if the caller address is zero.
        fn assert_only_relayer(self: @ContractState) {
            let relayer: ContractAddress = self.relayer.read();
            let caller: ContractAddress = get_caller_address();
            assert(!caller.is_zero(), Errors::ZERO_ADDRESS_CALLER);
            assert(caller == relayer, Errors::NOT_RELAYER);
        }

        /// @notice Sets a new relayer address for the contract.
        /// @dev Checks that the new relayer address is not zero before setting it.
        /// @param new_relayer The address to be set as the new relayer.
        fn _set_relayer(ref self: ContractState, new_relayer: ContractAddress) {
            assert(!new_relayer.is_zero(), Errors::ZERO_ADDRESS_RELAYER);
            self.relayer.write(new_relayer);
        }
    }
}
