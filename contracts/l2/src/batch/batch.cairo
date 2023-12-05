#[starknet::component]
mod BatchComponent {
    use openzeppelin::token::erc20::interface;
    use pooling4626::batch::interface::IBatch;
    use starknet::{
        get_caller_address, contract_address::{ContractAddress}, syscalls::{call_contract_syscall}
    };
    use zeroable::Zeroable;
    use traits::{TryInto, Into};
    use option::OptionTrait;
    use array::{ArrayDefault};

    use openzeppelin::{
        token::erc20::interface::{
            IERC20CamelDispatcher, IERC20CamelDispatcherTrait, IERC20CamelLibraryDispatcher
        }
    };

    #[storage]
    struct Storage {
        /// Gas token, can be eth or other. Must implement camelCase 
        Batch_gas_token: IERC20CamelDispatcher,
        /// Relayer address that can set the required gas per user
        Batch_relayer: ContractAddress,
        /// gas fees collector
        Batch_fees_collector: ContractAddress,
        /// gas oracle address
        Batch_gas_oracle: ContractAddress,
        /// gas oracle selector to fetch current L1 gas price
        Batch_gas_oracle_selector: felt252,
        /// Required gas per batch
        Batch_gas_required: u256,
        /// amount of participants to handle batch
        Batch_participant_required: u256,
        /// Current Batch Counter
        Batch_counter: u256,
        /// Last Handled Batch Counter
        Batch_handled_counter: u256,
        /// Current Participants in the batch
        Batch_participant_counter: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        RelayerSet: RelayerSet,
        FeeCollectorSet: FeeCollectorSet,
        GasOracleSet: GasOracleSet,
        GasOracleSelectorSet: GasOracleSelectorSet,
        GasRequiredUpdated: GasRequiredUpdated,
        ParticipantRequiredUpdated: ParticipantRequiredUpdated
    }

    #[derive(Drop, starknet::Event)]
    struct RelayerSet {
        relayer: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct FeeCollectorSet {
        fees_collector: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct GasOracleSet {
        gas_oracle: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct GasOracleSelectorSet {
        gas_oracle_selector: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct GasRequiredUpdated {
        gas_required: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ParticipantRequiredUpdated {
        participant_required: u256
    }


    mod Errors {
        const NOT_RELAYER: felt252 = 'Caller is not the relayer';
        const ZERO_ADDRESS_CALLER: felt252 = 'Caller is the zero address';
        const ZERO_ADDRESS_GAS_TOKEN: felt252 = 'Gas token is the zero address';
        const ZERO_ADDRESS_RELAYER: felt252 = 'Relayer is the zero address';
        const ZERO_ADDRESS_FEES_COLLECTOR: felt252 = 'Collector is the zero address';
        const ZERO_ADDRESS_GAS_ORACLE: felt252 = 'Gas oracle is the zero address';
        const ZERO_VALUE_GAS_ORACLE_SELECTOR: felt252 = 'Gas oracle selector is zero';
        const ZERO_AMOUNT_GAS_REQUIRED: felt252 = 'Gas Required is zero';
        const ZERO_AMOUNT_PARTICIPANT_REQUIRED: felt252 = 'Participant required is zero';
        const INVALID_PARTICPIANT_REQUIRED: felt252 = 'Participant required too low';
        const INVALID_PARTICIPANT_PAY_AMOUNT: felt252 = 'Participant pay amount too big';
        const SEQUENTIAL_EXECUTION: felt252 = 'Nonce handled is invalid';
        const BATCH_NOT_HANDLED: felt252 = 'Batch has not been handled';
    }

    //
    // External
    //

    #[embeddable_as(BatchImpl)]
    impl Batch<
        TContractState, +HasComponent<TContractState>
    > of IBatch<ComponentState<TContractState>> {
        ///////////////
        /// Getters ///
        ///////////////

        /// @notice Reads and returns the IERC20CamelDispatcher instance associated with gas tokens.
        /// @return IERC20CamelDispatcher The current gas token dispatcher.
        fn gas_token(self: @ComponentState<TContractState>) -> IERC20CamelDispatcher {
            self.Batch_gas_token.read()
        }

        /// @notice Reads and returns the current relayer contract address.
        /// @return ContractAddress The address of the relayer contract.
        fn relayer(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Batch_relayer.read()
        }

        /// @notice Reads and returns the current fees collector contract address.
        /// @return ContractAddress The address of the fees collector contract.
        fn fees_collector(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Batch_fees_collector.read()
        }

        /// @notice Reads and returns the current gas oracle contract address.
        /// @return ContractAddress The address of the gas oracle contract.
        fn gas_oracle(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Batch_gas_oracle.read()
        }

        /// @notice Reads and returns the selector for the gas oracle.
        /// @return felt252 The selector value for the gas oracle.
        fn gas_oracle_selector(self: @ComponentState<TContractState>) -> felt252 {
            self.Batch_gas_oracle_selector.read()
        }

        /// @notice Reads and returns the required gas amount.
        /// @return u256 The required gas amount.
        fn gas_required(self: @ComponentState<TContractState>) -> u256 {
            self.Batch_gas_required.read()
        }

        /// @notice Reads and returns the required number of participants.
        /// @return u256 The required number of participants.
        fn participant_required(self: @ComponentState<TContractState>) -> u256 {
            self.Batch_participant_required.read()
        }

        /// @notice Reads and returns the current counter value.
        /// @return u256 The current counter value.
        fn counter(self: @ComponentState<TContractState>) -> u256 {
            self.Batch_counter.read()
        }

        /// @notice Reads and returns the handled counter value.
        /// @return u256 The handled counter value.
        fn handled_counter(self: @ComponentState<TContractState>) -> u256 {
            self.Batch_handled_counter.read()
        }

        /// @notice Reads and returns the participant counter value.
        /// @return u256 The participant counter value.
        fn participant_counter(self: @ComponentState<TContractState>) -> u256 {
            self.Batch_participant_counter.read()
        }

        /// @notice Calculates and returns the gas required per participant.
        /// @return u256 The gas required per participant.
        fn gas_required_per_participant(self: @ComponentState<TContractState>) -> u256 {
            self._gas_required_per_participant()
        }

        /// @notice Calculates and returns the remaining participants needed to close the batch.
        /// @return u256 The remaining participants to close the batch.
        fn remaing_participant_to_close_batch(self: @ComponentState<TContractState>) -> u256 {
            self._remaing_participant_to_close_batch()
        }

        /// @notice Converts gas units to gas fee.
        /// @param gas_unit The gas units to convert.
        /// @return u256 The gas fee corresponding to the provided gas units.
        fn gas_unit_to_gas_fee(self: @ComponentState<TContractState>, gas_unit: u256) -> u256 {
            self._gas_unit_to_gas_fee(gas_unit)
        }

        /// @notice Calculates and returns the gas fee required per participant.
        /// @return u256 The gas fee required per participant.
        fn gas_fee_required_per_participant(self: @ComponentState<TContractState>) -> u256 {
            self._gas_fee_required_per_participant()
        }


        ///////////////
        /// Setters ///
        ///////////////

        /// @notice Sets a new gas token dispatcher.
        /// @dev Can only be called by the current relayer.
        /// @param gas_token The new IERC20CamelDispatcher instance to be set as the gas token dispatcher.
        fn set_gas_token(
            ref self: ComponentState<TContractState>, gas_token: IERC20CamelDispatcher
        ) {
            self.assert_only_relayer();
            self._set_gas_token(gas_token);
        }

        /// @notice Sets a new relayer contract address.
        /// @dev Can only be called by the current relayer.
        /// @param relayer The new ContractAddress to be set as the relayer.
        fn set_relayer(ref self: ComponentState<TContractState>, relayer: ContractAddress) {
            self.assert_only_relayer();
            self._set_relayer(relayer);
        }

        /// @notice Sets a new fees collector contract address.
        /// @dev Can only be called by the current relayer.
        /// @param fees_collector The new ContractAddress to be set as the fees collector.
        fn set_fee_collector(
            ref self: ComponentState<TContractState>, fees_collector: ContractAddress
        ) {
            self.assert_only_relayer();
            self._set_fees_collector(fees_collector);
        }

        /// @notice Sets a new gas oracle contract address.
        /// @dev Can only be called by the current relayer.
        /// @param gas_oracle The new ContractAddress to be set as the gas oracle.
        fn set_gas_oracle(ref self: ComponentState<TContractState>, gas_oracle: ContractAddress) {
            self.assert_only_relayer();
            self._set_gas_oracle(gas_oracle);
        }

        /// @notice Sets a new gas oracle selector.
        /// @dev Can only be called by the current relayer.
        /// @param gas_oracle_selector The new selector value for the gas oracle.
        fn set_gas_oracle_selector(
            ref self: ComponentState<TContractState>, gas_oracle_selector: felt252
        ) {
            self.assert_only_relayer();
            self._set_gas_oracle_selector(gas_oracle_selector);
        }

        /// @notice Sets a new required gas amount.
        /// @dev Can only be called by the current relayer.
        /// @param gas_required The new gas amount to be set as required.
        fn set_gas_required(ref self: ComponentState<TContractState>, gas_required: u256) {
            self.assert_only_relayer();
            self._set_gas_required(gas_required);
        }

        /// @notice Sets a new required number of participants.
        /// @dev Can only be called by the current relayer.
        /// @param participant_required The new number of participants to be set as required.
        fn set_participant_required(
            ref self: ComponentState<TContractState>, participant_required: u256
        ) {
            self.assert_only_relayer();
            self._set_participant_required(participant_required);
        }
        
    }


    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {

        /// @notice Initializes the contract with given parameters.
        /// @param gas_token The initial gas token dispatcher.
        /// @param relayer The initial relayer contract address.
        /// @param fees_collector The initial fees collector contract address.
        /// @param gas_oracle The initial gas oracle contract address.
        /// @param gas_oracle_selector The initial gas oracle selector.
        /// @param gas_required The initial required gas amount.
        /// @param participant_required The initial required number of participants.
        fn initializer(
            ref self: ComponentState<TContractState>,
            gas_token: IERC20CamelDispatcher,
            relayer: ContractAddress,
            fees_collector: ContractAddress,
            gas_oracle: ContractAddress,
            gas_oracle_selector: felt252,
            gas_required: u256,
            participant_required: u256
        ) {
            self._set_gas_token(gas_token);
            self._set_relayer(relayer);
            self._set_fees_collector(fees_collector);
            self._set_gas_oracle(gas_oracle);
            self._set_gas_oracle_selector(gas_oracle_selector);
            self._set_gas_required(gas_required);
            self._set_participant_required(participant_required);
            self.Batch_counter.write(1);
        }

        

        /// @notice Asserts that the caller of the function is the designated relayer.
        /// @dev Throws an error if the caller is not the relayer or if the caller address is zero.
        fn assert_only_relayer(self: @ComponentState<TContractState>) {
            let relayer: ContractAddress = self.Batch_relayer.read();
            let caller: ContractAddress = get_caller_address();
            assert(!caller.is_zero(), Errors::ZERO_ADDRESS_CALLER);
            assert(caller == relayer, Errors::NOT_RELAYER);
        }

        /// @notice Sets the gas token used by the contract.
        /// @dev Checks that the gas token address is not zero before setting it.
        /// @param gas_token The IERC20CamelDispatcher instance to be set as the gas token.
        fn _set_gas_token(
            ref self: ComponentState<TContractState>, gas_token: IERC20CamelDispatcher
        ) {
            assert(!gas_token.contract_address.is_zero(), Errors::ZERO_ADDRESS_GAS_TOKEN);
            self.Batch_gas_token.write(gas_token);
        }

        /// @notice Sets the relayer address for the contract.
        /// @dev Checks that the relayer address is not zero before setting it.
        /// @param relayer The ContractAddress to be set as the new relayer.
        fn _set_relayer(ref self: ComponentState<TContractState>, relayer: ContractAddress) {
            assert(!relayer.is_zero(), Errors::ZERO_ADDRESS_RELAYER);
            self.Batch_relayer.write(relayer);
        }

        /// @notice Sets the fees collector address for the contract.
        /// @dev Checks that the fees collector address is not zero before setting it.
        /// @param fees_collector The ContractAddress to be set as the new fees collector.
        fn _set_fees_collector(
            ref self: ComponentState<TContractState>, fees_collector: ContractAddress
        ) {
            assert(!fees_collector.is_zero(), Errors::ZERO_ADDRESS_FEES_COLLECTOR);
            self.Batch_fees_collector.write(fees_collector);
        }

        /// @notice Sets the gas oracle address for the contract.
        /// @dev Checks that the gas oracle address is not zero before setting it.
        /// @param gas_oracle The ContractAddress to be set as the new gas oracle.
        fn _set_gas_oracle(ref self: ComponentState<TContractState>, gas_oracle: ContractAddress) {
            assert(!gas_oracle.is_zero(), Errors::ZERO_ADDRESS_GAS_ORACLE);
            self.Batch_gas_oracle.write(gas_oracle);
        }

        /// @notice Sets the gas oracle selector for the contract.
        /// @dev Checks that the gas oracle selector is not zero before setting it.
        /// @param gas_oracle_selector The selector value to be set for the gas oracle.
        fn _set_gas_oracle_selector(
            ref self: ComponentState<TContractState>, gas_oracle_selector: felt252
        ) {
            assert(!gas_oracle_selector.is_zero(), Errors::ZERO_VALUE_GAS_ORACLE_SELECTOR);
            self.Batch_gas_oracle_selector.write(gas_oracle_selector);
        }

        /// @notice Sets the required gas amount for the contract.
        /// @dev Checks that the required gas amount is not zero before setting it.
        /// @param gas_required The u256 value to be set as the required gas amount.
        fn _set_gas_required(ref self: ComponentState<TContractState>, gas_required: u256) {
            assert(!gas_required.is_zero(), Errors::ZERO_AMOUNT_GAS_REQUIRED);
            self.Batch_gas_required.write(gas_required);
        }

        /// @notice Sets the required number of participants for the contract.
        /// @dev Checks that the required number of participants is not zero and is greater than the current participant counter before setting it.
        /// @param participant_required The u256 value to be set as the required number of participants.
        fn _set_participant_required(
            ref self: ComponentState<TContractState>, participant_required: u256
        ) {
            assert(!participant_required.is_zero(), Errors::ZERO_AMOUNT_PARTICIPANT_REQUIRED);
            let participant_counter = self.Batch_participant_counter.read();
            assert(participant_required > participant_counter, Errors::INVALID_PARTICPIANT_REQUIRED);
            self.Batch_participant_required.write(participant_required);
        }

        /// @notice Calculates and returns the gas required per participant.
        /// @return u256 The calculated gas required per participant.
        fn _gas_required_per_participant(self: @ComponentState<TContractState>) -> u256 {
            let gas_required = self.Batch_gas_required.read();
            let participant_required = self.Batch_participant_required.read();
            gas_required / participant_required
        }


        /// @notice Calculates and returns the gas fee based on provided gas units.
        /// @param gas_unit The number of gas units for which the fee is calculated.
        /// @return u256 The calculated gas fee for the given gas units.
        fn _gas_unit_to_gas_fee(self: @ComponentState<TContractState>, gas_unit: u256) -> u256 {
            let gas_oracle = self.Batch_gas_oracle.read();
            let gas_oracle_selector = self.Batch_gas_oracle_selector.read();
            let mut res: Span<felt252> = call_contract_syscall(
                gas_oracle, gas_oracle_selector, (ArrayDefault::<felt252>::default()).span()
            )
                .unwrap();
            let mut l1_gas_price: u256 = Serde::<u256>::deserialize(ref res).unwrap();
            gas_unit * l1_gas_price
        }

        /// @notice Calculates and returns the remaining number of participants required to close the batch.
        /// @return u256 The remaining number of participants required.
        fn _remaing_participant_to_close_batch(self: @ComponentState<TContractState>) -> u256 {
            let required_participant = self.Batch_participant_required.read();
            let participant_counter = self.Batch_participant_counter.read();
            required_participant - participant_counter
        }

        /// @notice Calculates and returns the required gas fee per participant.
        /// @return u256 The required gas fee per participant.
        fn _gas_fee_required_per_participant(self: @ComponentState<TContractState>) -> u256 {
            let gas_unit_per_participant = self._gas_required_per_participant();
            self._gas_unit_to_gas_fee(gas_unit_per_participant)
        }

        /// @notice Charges the user the appropriate gas fee for participation.
        /// @param caller The address of the participant to be charged.
        /// @param participant_pay_amount The number of participants the caller represents.
        /// @return tuple A tuple containing the current batch counter and a boolean indicating if the batch is closed.
        fn _charge_user(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            participant_pay_amount: u256
        ) -> (u256, bool) {
            assert(!caller.is_zero(), Errors::ZERO_ADDRESS_CALLER);
            let remaing_participant_to_close_batch = self._remaing_participant_to_close_batch();
            assert(
                participant_pay_amount <= remaing_participant_to_close_batch,
                Errors::INVALID_PARTICIPANT_PAY_AMOUNT
            );
            let gas_fee_required_per_participant = self._gas_fee_required_per_participant();
            let amount_to_pay = gas_fee_required_per_participant * participant_pay_amount;
            let gas_token = self.Batch_gas_token.read();
            let fees_collector = self.Batch_fees_collector.read();
            gas_token.transferFrom(caller, fees_collector, amount_to_pay);
            let current_counter = self.Batch_counter.read();
            if remaing_participant_to_close_batch == participant_pay_amount {
                self.Batch_participant_counter.write(0);
                self.Batch_counter.write(current_counter + 1);
                return (current_counter, true);
            } else {
                return (current_counter, false);
            }
        }

        /// @notice Forcibly closes the current batch and resets the participant counter.
        /// @return u256 The updated batch counter after closing the batch.
        fn _close_batch_force(ref self: ComponentState<TContractState>) -> u256 {
            self.Batch_participant_counter.write(0);
            let current_counter = self.Batch_counter.read();
            self.Batch_counter.write(current_counter + 1);
            current_counter
        }

        /// @notice Handles nonce validation for batch execution.
        /// @param nonce The nonce value to be validated against the handled counter.
        fn _handle_nonce(ref self: ComponentState<TContractState>, nonce: u256) {
            let handled_counter = self.Batch_handled_counter.read();
            assert(nonce == handled_counter + 1, Errors::SEQUENTIAL_EXECUTION);
            self.Batch_handled_counter.write(nonce);
        }

        /// @notice Asserts that a batch with the given nonce has already been handled.
        /// @param nonce The nonce of the batch to check.
        fn assert_batch_handled(self: @ComponentState<TContractState>, nonce: u256) {
            let handled_counter = self.Batch_handled_counter.read();
            assert(nonce <= handled_counter, Errors::BATCH_NOT_HANDLED);
        }

    }
}
