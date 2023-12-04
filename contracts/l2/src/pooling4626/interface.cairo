
use starknet::ContractAddress;
use pooling4626::pooling4626::action::Action;

#[starknet::interface]
trait IPooling4626<TState> {
    fn user_amount_for_nonce(self: @TState, nonce: u256, user: ContractAddress) -> ((u256, bool), (u256, bool));
    fn users_for_nonce(self: @TState, nonce: u256) -> (Array<ContractAddress>, Array<ContractAddress>);
    fn deposit(ref self: TState, underlying_amount: u256, participant_pay_amount: u256) -> (u256, Action);
    fn redeem(ref self: TState, yield_amount: u256, participant_pay_amount: u256) -> (u256, Action);
    fn harvest(ref self: TState, nonce: u256, action: Action) -> u256;
    fn close_batch_force(ref self: TState, yield_amount: u256, participant_pay_amount: u256);
    
}
