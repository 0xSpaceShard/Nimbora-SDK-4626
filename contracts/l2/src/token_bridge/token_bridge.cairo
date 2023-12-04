use starknet::ContractAddress;

#[starknet::interface]
trait IMintableToken<TStorage> {
    fn permissionedMint(ref self: TStorage, account: ContractAddress, amount: u256);
    fn permissionedBurn(ref self: TStorage, account: ContractAddress, amount: u256);
}

#[starknet::contract]
mod TokenBridge {
    use super::{ContractAddress, IMintableTokenDispatcher, IMintableTokenDispatcherTrait};
    use zeroable::Zeroable;
    use array::{ArrayTrait, ArrayDefault};
    use traits::{TryInto, Into};
    use option::OptionTrait;
    use starknet::{
        get_caller_address, contract_address::{Felt252TryIntoContractAddress},
        syscalls::send_message_to_l1_syscall
    };
    use openzeppelin::{
        token::erc20::interface::{
            IERC20CamelDispatcher, IERC20CamelDispatcherTrait
        }
    };
    use pooling4626::token_bridge::interface::{ITokenBridge};


    const ZERO_ADDRESS: felt252 = 'ZERO_ADDRESS';
    const ZERO_AMOUNT: felt252 = 'ZERO_AMOUNT';
    const INCORRECT_BALANCE: felt252 = 'INCORRECT_BALANCE';
    const INSUFFICIENT_FUNDS: felt252 = 'INSUFFICIENT_FUNDS';
    const UNINITIALIZED_L1_BRIDGE_ADDRESS: felt252 = 'UNINITIALIZED_L1_BRIDGE';
    const EXPECTED_FROM_BRIDGE_ONLY: felt252 = 'EXPECTED_FROM_BRIDGE';
    const UNINITIALIZED_TOKEN: felt252 = 'UNINITIALIZED_TOKEN';
    const WITHDRAW_MESSAGE: felt252 = 0;

    #[storage]
    struct Storage {
        _l2_address: ContractAddress,
        _l1_bridge: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        WithdrawInitiated: WithdrawInitiated,
        DepositHandled: DepositHandled,
    }

    #[derive(Drop, starknet::Event)]
    struct WithdrawInitiated {
        l1_recipient: felt252,
        amount: u256,
        caller_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct DepositHandled {
        account: felt252,
        amount: u256
    }


    #[constructor]
    fn constructor(ref self: ContractState, l2_address: ContractAddress, l1_bridge: felt252) {
        assert(l2_address.is_non_zero(), ZERO_ADDRESS);
        assert(l1_bridge.is_non_zero(), ZERO_ADDRESS);
        self._l2_address.write(l2_address);
        self._l1_bridge.write(l1_bridge);
    }

    #[external(v0)]
    impl TokenBridgeImpl of ITokenBridge<ContractState> {
        fn get_l2_token(self: @ContractState) -> ContractAddress {
            self._l2_address.read()
        }

        fn get_l1_bridge(self: @ContractState) -> felt252 {
            self._l1_bridge.read()
        }

        fn initiate_withdraw(ref self: ContractState, l1_recipient: felt252, amount: u256) {
            assert(amount != 0, ZERO_AMOUNT);

            // Check token and bridge addresses are valid.
            let l1_bridge = self._l1_bridge.read();
            assert(l1_bridge.is_non_zero(), ZERO_ADDRESS);

            let l2_token = self._l2_address.read();
            assert(l2_token.is_non_zero(), ZERO_ADDRESS);

            // Call burn on l2_token contract and verify success.

            let caller_address = get_caller_address();
            let balance_before = IERC20CamelDispatcher {
                contract_address: l2_token
            }.balanceOf(caller_address);

            assert(amount <= balance_before, INSUFFICIENT_FUNDS);

            let mintable_token = IMintableTokenDispatcher {
                contract_address: l2_token
            };
            mintable_token.permissionedBurn(caller_address, amount);

            let balance_after = IERC20CamelDispatcher {
                contract_address: l2_token
            }.balanceOf(caller_address);

            assert(balance_after == balance_before - amount, INCORRECT_BALANCE);

            // Send the message.
            let mut message_payload: Array<felt252> = ArrayTrait::new();
            message_payload.append(WITHDRAW_MESSAGE);
            message_payload.append(l1_recipient);
            message_payload.append(amount.low.into());
            message_payload.append(amount.high.into());
            send_message_to_l1_syscall(to_address: l1_bridge, payload: message_payload.span());
            self
                .emit(
                    Event::WithdrawInitiated(
                        WithdrawInitiated {
                            l1_recipient: l1_recipient,
                            amount: amount,
                            caller_address: caller_address
                        }
                    )
                );
        }

        fn set_l2_token(ref self: ContractState, l2_token_address: ContractAddress) {
            assert(l2_token_address.is_non_zero(), ZERO_ADDRESS);
            self._l2_address.write(l2_token_address);
        }

        fn set_l1_bridge(ref self: ContractState, l1_bridge_address: felt252) {
            assert(l1_bridge_address.is_non_zero(), ZERO_ADDRESS);
            self._l1_bridge.write(l1_bridge_address);
        }

        fn handle_deposit(
            ref self: ContractState, from_address: felt252, account: felt252, amount: u256
        ) {
            // Check account address is valid.
            assert(account.is_non_zero(), ZERO_ADDRESS);

            // Check token and bridge addresses are initialized and the handler invoked by the bridge.
            let l1_bridge = self._l1_bridge.read();
            assert(l1_bridge.is_non_zero(), UNINITIALIZED_L1_BRIDGE_ADDRESS);

            assert(from_address == l1_bridge, EXPECTED_FROM_BRIDGE_ONLY);

            let l2_token = self._l2_address.read();
            assert(l2_token.is_non_zero(), UNINITIALIZED_TOKEN);

            // Call mint on l2_token contract and verify success.
            let balance_before = IERC20CamelDispatcher {
                contract_address: l2_token
            }.balanceOf(account.try_into().unwrap());

            let expected_balance_after = balance_before + amount;

            let mintable_token = IMintableTokenDispatcher {contract_address: l2_token};
            mintable_token.permissionedMint(account.try_into().unwrap(), amount);

            let balance_after = IERC20CamelDispatcher {
                contract_address: l2_token
            }.balanceOf(account.try_into().unwrap());
            assert(balance_after == balance_before + amount, INCORRECT_BALANCE);
            self.emit(Event::DepositHandled(DepositHandled { account: account, amount: amount }));
        }
    }
}
