use starknet::ContractAddress;

#[starknet::interface]
trait IMintableToken<TStorage> {
    fn permissionedMint(ref self: TStorage, account: ContractAddress, amount: u256);
    fn permissionedBurn(ref self: TStorage, account: ContractAddress, amount: u256);
}
