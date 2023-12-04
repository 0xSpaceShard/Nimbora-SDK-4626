use starknet::ContractAddress;

#[starknet::interface]
trait IGasOracle<TState> {
    fn relayer(self: @TState) -> ContractAddress;
    fn l1_gas_price(self: @TState) -> u256;
    fn last_update(self: @TState) -> u64;
    fn set_relayer(ref self: TState, new_relayer: ContractAddress);
    fn set_l1_gas_price(ref self: TState, gas_price: u256);
}
