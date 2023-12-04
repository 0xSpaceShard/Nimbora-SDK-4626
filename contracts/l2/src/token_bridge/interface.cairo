use starknet::ContractAddress;

#[starknet::interface]
trait ITokenBridge<TStorage> {
    fn get_l1_bridge(self: @TStorage) -> felt252;
    fn get_l2_token(self: @TStorage) -> ContractAddress;
    fn set_l1_bridge(ref self: TStorage, l1_bridge_address: felt252);
    fn set_l2_token(ref self: TStorage, l2_token_address: ContractAddress);
    fn initiate_withdraw(ref self: TStorage, l1_recipient: felt252, amount: u256);
    fn handle_deposit(ref self: TStorage, from_address: felt252, account: felt252, amount: u256);
}
