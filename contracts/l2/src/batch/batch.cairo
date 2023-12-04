#[starknet::component]
mod BatchComponent {
    use openzeppelin::token::erc20::interface;
    use pooling4626::batch::interface::IBatch;
    use starknet::{
        get_caller_address, 
        contract_address::{
            ContractAddress
        },
        syscalls::{call_contract_syscall}
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
    impl Batch<TContractState, +HasComponent<TContractState>> of IBatch<ComponentState<TContractState>> {

        ///////////////
        /// Getters ///
        ///////////////

        fn gas_token(self: @ComponentState<TContractState>) -> IERC20CamelDispatcher {
            self.Batch_gas_token.read()
        }

        fn relayer(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Batch_relayer.read()
        }

        fn fees_collector(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Batch_fees_collector.read()
        }

        fn gas_oracle(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Batch_gas_oracle.read()
        }

        fn gas_oracle_selector(self: @ComponentState<TContractState>) -> felt252 {
            self.Batch_gas_oracle_selector.read()
        }

        fn gas_required(self: @ComponentState<TContractState>) -> u256 {
            self.Batch_gas_required.read()
        }

        fn participant_required(self: @ComponentState<TContractState>) -> u256 {
            self.Batch_participant_required.read()
        }

        fn counter(self: @ComponentState<TContractState>) -> u256 {
            self.Batch_counter.read()
        }

        fn handled_counter(self: @ComponentState<TContractState>) -> u256 {
            self.Batch_handled_counter.read()
        }

        fn participant_counter(self: @ComponentState<TContractState>) -> u256 {
            self.Batch_participant_counter.read()
        }

        fn gas_required_per_participant(self: @ComponentState<TContractState>) -> u256 {
            self._gas_required_per_participant()
        }

        fn remaing_participant_to_close_batch(self: @ComponentState<TContractState>) -> u256 {
            self._remaing_participant_to_close_batch()
        }

        fn gas_unit_to_gas_fee(self: @ComponentState<TContractState>, gas_unit: u256) -> u256 {
            self._gas_unit_to_gas_fee(gas_unit)
        }

        fn gas_fee_required_per_participant(self: @ComponentState<TContractState>) -> u256 {
            self._gas_fee_required_per_participant()
        }

        ///////////////
        /// Setters ///
        ///////////////

        fn set_gas_token(
            ref self: ComponentState<TContractState>, gas_token: IERC20CamelDispatcher
        ) {
            self.assert_only_relayer();
            self._set_gas_token(gas_token);
        }

        fn set_relayer(
            ref self: ComponentState<TContractState>, relayer: ContractAddress
        ) {
            self.assert_only_relayer();
            self._set_relayer(relayer);
        }

        fn set_fee_collector(
            ref self: ComponentState<TContractState>, fees_collector: ContractAddress
        ) {
            self.assert_only_relayer();
            self._set_fees_collector(fees_collector);
        }

        fn set_gas_oracle(
            ref self: ComponentState<TContractState>, gas_oracle: ContractAddress
        ) {
            self.assert_only_relayer();
            self._set_gas_oracle(gas_oracle);
        }

        fn set_gas_oracle_selector(
            ref self: ComponentState<TContractState>, gas_oracle_selector: felt252
        ) {
            self.assert_only_relayer();
            self._set_gas_oracle_selector(gas_oracle_selector);
        }

        fn set_gas_required(
            ref self: ComponentState<TContractState>, gas_required: u256
        ) {
            self.assert_only_relayer();
            self._set_gas_required(gas_required);
        }

        fn set_participant_required(
            ref self: ComponentState<TContractState>, participant_required: u256
        ) {
            self.assert_only_relayer();
            self._set_participant_required(participant_required);
        }

    }


    #[generate_trait]
    impl InternalImpl<TContractState, +HasComponent<TContractState>> of InternalTrait<TContractState> {
        
        fn initializer(ref self: ComponentState<TContractState>, gas_token: IERC20CamelDispatcher,relayer: ContractAddress, fees_collector: ContractAddress, gas_oracle: ContractAddress, gas_oracle_selector: felt252, gas_required: u256, participant_required: u256) {
            self._set_gas_token(gas_token);
            self._set_relayer(relayer);
            self._set_fees_collector(fees_collector);
            self._set_gas_oracle(gas_oracle);
            self._set_gas_oracle_selector(gas_oracle_selector);
            self._set_gas_required(gas_required);
            self._set_participant_required(participant_required);
            self.Batch_counter.write(1);
        }

        fn assert_only_relayer(self: @ComponentState<TContractState>) {
            let relayer: ContractAddress = self.Batch_relayer.read();
            let caller: ContractAddress = get_caller_address();
            assert(!caller.is_zero(), Errors::ZERO_ADDRESS_CALLER);
            assert(caller == relayer, Errors::NOT_RELAYER);
        }

        fn _set_gas_token(
            ref self: ComponentState<TContractState>, gas_token: IERC20CamelDispatcher
        ) {
            assert(!gas_token.contract_address.is_zero(), Errors::ZERO_ADDRESS_GAS_TOKEN);
            self.Batch_gas_token.write(gas_token);
        }

        fn _set_relayer(
            ref self: ComponentState<TContractState>, relayer: ContractAddress
        ) {
            assert(!relayer.is_zero(), Errors::ZERO_ADDRESS_RELAYER);
            self.Batch_relayer.write(relayer);
        }

        fn _set_fees_collector(
            ref self: ComponentState<TContractState>, fees_collector: ContractAddress
        ) {
            assert(!fees_collector.is_zero(), Errors::ZERO_ADDRESS_FEES_COLLECTOR);
            self.Batch_fees_collector.write(fees_collector);
        }

        fn _set_gas_oracle(
            ref self: ComponentState<TContractState>, gas_oracle: ContractAddress
        ) {
            assert(!gas_oracle.is_zero(), Errors::ZERO_ADDRESS_GAS_ORACLE);
            self.Batch_gas_oracle.write(gas_oracle);
        }

        fn _set_gas_oracle_selector(
            ref self: ComponentState<TContractState>, gas_oracle_selector: felt252
        ) {
            assert(!gas_oracle_selector.is_zero(), Errors::ZERO_VALUE_GAS_ORACLE_SELECTOR);
            self.Batch_gas_oracle_selector.write(gas_oracle_selector);
        }

        fn _set_gas_required(
            ref self: ComponentState<TContractState>, gas_required: u256
        ) {
            assert(!gas_required.is_zero(), Errors::ZERO_AMOUNT_GAS_REQUIRED);
            self.Batch_gas_required.write(gas_required);
        }

        fn _set_participant_required(
            ref self: ComponentState<TContractState>, participant_required: u256
        ) {
            assert(!participant_required.is_zero(), Errors::ZERO_AMOUNT_PARTICIPANT_REQUIRED);
            let participant_counter = self.Batch_participant_counter.read();
            assert(participant_required > participant_counter, Errors::INVALID_PARTICPIANT_REQUIRED);
            self.Batch_participant_required.write(participant_required);
        }


        fn _gas_required_per_participant(self: @ComponentState<TContractState>) -> u256 {
            let gas_required = self.Batch_gas_required.read();
            let participant_required = self.Batch_participant_required.read();
            gas_required / participant_required
        }

        fn _gas_unit_to_gas_fee(self: @ComponentState<TContractState>, gas_unit: u256) -> u256 {
            let gas_oracle = self.Batch_gas_oracle.read();
            let gas_oracle_selector = self.Batch_gas_oracle_selector.read();
            let mut res : Span<felt252> = call_contract_syscall(gas_oracle, gas_oracle_selector, (ArrayDefault::<felt252>::default()).span()).unwrap();
            let mut l1_gas_price: u256 = Serde::<u256>::deserialize(ref res).unwrap();
            gas_unit * l1_gas_price
        }


        fn _remaing_participant_to_close_batch(self: @ComponentState<TContractState>) -> u256 {
            let required_participant = self.Batch_participant_required.read();
            let participant_counter = self.Batch_participant_counter.read();
            required_participant - participant_counter
        }

        fn _gas_fee_required_per_participant(self: @ComponentState<TContractState>) -> u256 {
            let gas_unit_per_participant = self._gas_required_per_participant();    
            self._gas_unit_to_gas_fee(gas_unit_per_participant)
        }


        fn _charge_user(ref self: ComponentState<TContractState>, caller: ContractAddress, participant_pay_amount: u256) -> (u256, bool) {
            assert(!caller.is_zero(), Errors::ZERO_ADDRESS_CALLER);
            let remaing_participant_to_close_batch = self._remaing_participant_to_close_batch();
            assert(participant_pay_amount <= remaing_participant_to_close_batch, Errors::INVALID_PARTICIPANT_PAY_AMOUNT);
            let gas_fee_required_per_participant = self._gas_fee_required_per_participant();
            let amount_to_pay = gas_fee_required_per_participant * participant_pay_amount;
            let gas_token = self.Batch_gas_token.read();
            let fees_collector = self.Batch_fees_collector.read();
            gas_token.transferFrom(caller, fees_collector, amount_to_pay);
            let current_counter = self.Batch_counter.read();            
            if remaing_participant_to_close_batch == participant_pay_amount {
                self.Batch_participant_counter.write(0);
                self.Batch_counter.write(current_counter + 1);
                (current_counter, true)
            } else {
                (current_counter, false)
            }
        }

        fn _close_batch_force(ref self: ComponentState<TContractState>) -> u256 {
            self.Batch_participant_counter.write(0);
            let current_counter = self.Batch_counter.read();
            self.Batch_counter.write(current_counter + 1);
            current_counter
        }

        fn _handle_nonce(ref self: ComponentState<TContractState>, nonce: u256) {
            let handled_counter = self.Batch_handled_counter.read();
            assert(nonce == handled_counter + 1, Errors::SEQUENTIAL_EXECUTION);
            self.Batch_handled_counter.write(nonce);
        }

        fn assert_batch_handled(self: @ComponentState<TContractState>, nonce: u256) {
            let handled_counter = self.Batch_handled_counter.read();
            assert(nonce <= handled_counter, Errors::BATCH_NOT_HANDLED);
        }
    }
}