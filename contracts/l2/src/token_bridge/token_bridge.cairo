use starknet::ContractAddress;

#[starknet::contract]
mod TokenBridge {
    use super::{ContractAddress};
    use zeroable::Zeroable;
    use array::{ArrayTrait, ArrayDefault};
    use traits::{TryInto, Into};
    use option::OptionTrait;
    use starknet::{
        get_caller_address, contract_address::{Felt252TryIntoContractAddress},
        syscalls::send_message_to_l1_syscall
    };
    use openzeppelin::{
        token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait}
    };
    use pooling4626::token_bridge::interface::{ITokenBridge};
    use pooling4626::token::interface::{IMintableTokenDispatcher, IMintableTokenDispatcherTrait};

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

    /// @notice Constructor for the contract, initializing it with the L2 token and L1 bridge addresses.
    /// @param l2_address The address of the L2 token contract.
    /// @param l1_bridge The address of the L1 bridge contract.
    /// @dev Ensures that neither the L2 token address nor the L1 bridge address is zero before initializing the contract state.
    #[constructor]
    fn constructor(ref self: ContractState, l2_address: ContractAddress, l1_bridge: felt252) {
        assert(l2_address.is_non_zero(), ZERO_ADDRESS);
        assert(l1_bridge.is_non_zero(), ZERO_ADDRESS);
        self._l2_address.write(l2_address);
        self._l1_bridge.write(l1_bridge);
    }

    #[external(v0)]
    impl TokenBridgeImpl of ITokenBridge<ContractState> {
        
        /// @notice Retrieves the address of the L2 token contract.
        /// @return The address of the L2 token contract.
        fn get_l2_token(self: @ContractState) -> ContractAddress {
            self._l2_address.read()
        }

        /// @notice Retrieves the address of the L1 bridge contract.
        /// @return The address of the L1 bridge contract.
        fn get_l1_bridge(self: @ContractState) -> felt252 {
            self._l1_bridge.read()
        }

        /// @notice Initiates a withdrawal process from L2 to L1.
        /// @param l1_recipient The address of the recipient on L1.
        /// @param amount The amount to withdraw.
        /// @dev Performs checks on the amount, L1 bridge, and L2 token addresses before proceeding with the withdrawal.
        /// Verifies the caller's balance before and after burning the L2 tokens, and sends a message to L1.
        fn initiate_withdraw(ref self: ContractState, l1_recipient: felt252, amount: u256) {
            assert(amount != 0, ZERO_AMOUNT);

            // Check token and bridge addresses are valid.
            let l1_bridge = self._l1_bridge.read();
            assert(l1_bridge.is_non_zero(), ZERO_ADDRESS);

            let l2_token = self._l2_address.read();
            assert(l2_token.is_non_zero(), ZERO_ADDRESS);

            // Call burn on l2_token contract and verify success.

            let caller_address = get_caller_address();
            let balance_before = IERC20CamelDispatcher { contract_address: l2_token }
                .balanceOf(caller_address);

            assert(amount <= balance_before, INSUFFICIENT_FUNDS);

            let mintable_token = IMintableTokenDispatcher { contract_address: l2_token };
            mintable_token.permissionedBurn(caller_address, amount);

            let balance_after = IERC20CamelDispatcher { contract_address: l2_token }
                .balanceOf(caller_address);

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


        /// @notice Sets the address of the L2 token contract.
        /// @param l2_token_address The address of the new L2 token contract.
        /// @dev Ensures that the provided L2 token address is not zero before updating the contract state.
        fn set_l2_token(ref self: ContractState, l2_token_address: ContractAddress) {
            assert(l2_token_address.is_non_zero(), ZERO_ADDRESS);
            self._l2_address.write(l2_token_address);
        }

        /// @notice Sets the address of the L1 bridge contract.
        /// @param l1_bridge_address The address of the new L1 bridge contract.
        /// @dev Ensures that the provided L1 bridge address is not zero before updating the contract state.
        fn set_l1_bridge(ref self: ContractState, l1_bridge_address: felt252) {
            assert(l1_bridge_address.is_non_zero(), ZERO_ADDRESS);
            self._l1_bridge.write(l1_bridge_address);
        }

        /// @notice Handles the deposit process from L1 to L2.
        /// @param from_address The address of the sender on L1.
        /// @param account The L2 account receiving the deposit.
        /// @param amount The amount being deposited.
        /// @dev Ensures the validity of account, L1 bridge, and L2 token addresses before proceeding.
        /// Checks that the deposit was initiated by the L1 bridge, mints L2 tokens, and verifies the updated balance.
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
            let balance_before = IERC20CamelDispatcher { contract_address: l2_token }
                .balanceOf(account.try_into().unwrap());

            let expected_balance_after = balance_before + amount;

            let mintable_token = IMintableTokenDispatcher { contract_address: l2_token };
            mintable_token.permissionedMint(account.try_into().unwrap(), amount);

            let balance_after = IERC20CamelDispatcher { contract_address: l2_token }
                .balanceOf(account.try_into().unwrap());
            assert(balance_after == balance_before + amount, INCORRECT_BALANCE);
            self.emit(Event::DepositHandled(DepositHandled { account: account, amount: amount }));
        }
    }
}
