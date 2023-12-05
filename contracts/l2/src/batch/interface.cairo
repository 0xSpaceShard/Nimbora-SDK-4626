use starknet::ContractAddress;

use openzeppelin::{token::erc20::interface::{IERC20CamelDispatcher}};

#[starknet::interface]
trait IBatch<TState> {
    fn gas_token(self: @TState) -> IERC20CamelDispatcher;
    fn relayer(self: @TState) -> ContractAddress;
    fn fees_collector(self: @TState) -> ContractAddress;
    fn gas_oracle(self: @TState) -> ContractAddress;
    fn gas_oracle_selector(self: @TState) -> felt252;
    fn gas_required(self: @TState) -> u256;
    fn participant_required(self: @TState) -> u256;
    fn counter(self: @TState) -> u256;
    fn handled_counter(self: @TState) -> u256;
    fn participant_counter(self: @TState) -> u256;
    fn gas_required_per_participant(self: @TState) -> u256;
    fn remaing_participant_to_close_batch(self: @TState) -> u256;
    fn gas_unit_to_gas_fee(self: @TState, gas_unit: u256) -> u256;
    fn gas_fee_required_per_participant(self: @TState) -> u256;


    fn set_gas_token(ref self: TState, gas_token: IERC20CamelDispatcher);
    fn set_relayer(ref self: TState, relayer: ContractAddress);
    fn set_fee_collector(ref self: TState, fees_collector: ContractAddress);
    fn set_gas_oracle(ref self: TState, gas_oracle: ContractAddress);
    fn set_gas_oracle_selector(ref self: TState, gas_oracle_selector: felt252);
    fn set_gas_required(ref self: TState, gas_required: u256);
    fn set_participant_required(ref self: TState, participant_required: u256);
}
