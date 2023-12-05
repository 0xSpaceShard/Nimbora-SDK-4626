#[starknet::contract]
mod Pooling4626 {
    use pooling4626::pooling4626::interface::IPooling4626;
    use openzeppelin::access::ownable::{OwnableComponent};
    use pooling4626::batch::batch::{BatchComponent};
    use pooling4626::token_bridge::interface::{ITokenBridgeDispatcher, ITokenBridgeDispatcherTrait};
    use pooling4626::pooling4626::action::{
        Action, ActionPartialEq, ActionHashTuppleOneImpl, ActionHashTuppleTwoImpl,
        ActionHashTuppleThreeImpl, ActionHashTuppleFourthImpl, DEPOSIT_ACTION, REDEEM_ACTION
    };

    use array::{ArrayTrait, ArrayDefault};
    use traits::{TryInto, Into};
    use option::OptionTrait;
    use serde::Serde;
    use openzeppelin::{
        token::erc20::interface::{
            IERC20CamelDispatcher, IERC20CamelDispatcherTrait, IERC20CamelLibraryDispatcher
        }
    };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: BatchComponent, storage: batch, event: BatchEvent);

    use starknet::{
        get_caller_address, EthAddress, SyscallResult, StorageBaseAddress,
        class_hash::{ClassHash, Felt252TryIntoClassHash},
        info::{get_contract_address, get_block_timestamp},
        contract_address::{ContractAddress, ContractAddressZeroable, Felt252TryIntoContractAddress},
        syscalls::{send_message_to_l1_syscall, replace_class_syscall}
    };

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl BatchImpl = BatchComponent::BatchImpl<ContractState>;
    impl BatchInternalImpl = BatchComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        batch: BatchComponent::Storage,
        l1_pooling: EthAddress,
        underlying: IERC20CamelDispatcher,
        yield: IERC20CamelDispatcher,
        underlying_bridge: ITokenBridgeDispatcher,
        yield_bridge: ITokenBridgeDispatcher,
        batch_amount: LegacyMap<(u256, Action, ContractAddress), (u256, bool)>,
        batch_users: LegacyMap<(u256, Action, felt252), ContractAddress>,
        batch_handled_amount: LegacyMap<(u256, Action), u256>,
        action_limit: LegacyMap<Action, (u256, u256)>
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        BatchEvent: BatchComponent::Event,
        ActionProcessed: ActionProcessed,
        HarvestProcessed: HarvestProcessed,
        BatchRequest: BatchRequest,
        BatchResponse: BatchResponse,
        LimitUpdated: LimitUpdated
    }


    #[derive(Drop, starknet::Event)]
    struct ActionProcessed {
        nonce: u256,
        action: Action,
        user: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct HarvestProcessed {
        nonce: u256,
        action: Action,
        user: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct BatchRequest {
        nonce: u256,
        total_deposited_amount: u256,
        total_redeemed_amount: u256
    }

    /// Informs when a batch has been processed on L1 successfuly.
    #[derive(Drop, starknet::Event)]
    struct BatchResponse {
        nonce: u256,
        total_underlying: u256,
        total_yield: u256
    }

    #[derive(Drop, starknet::Event)]
    struct LimitUpdated {
        action: Action,
        limit_low: u256,
        limit_high: u256
    }


    mod Errors {
        const BATCH_EMPTY: felt252 = 'Batch has no user requests';
        const USER_AMOUNT_NUL: felt252 = 'User amount nul';
        const AMOUNT_HARVESTED: felt252 = 'Amount already harvested';
        const WRONG_SENDER: felt252 = 'Sender is not l1 pooling';
        const INVALID_LIMIT: felt252 = 'Limit amount is invalid';
    }

    const PRECISION: u256 = 1000000000000000000;

    /// @notice Initializes the contract with various parameters including owner, gas token, fees collector, gas oracle, and more.
    /// @dev This constructor sets the initial state of the contract, including token bridges and action limits.
    /// @param owner The address to be set as the initial owner of the contract.
    /// @param gas_token The initial gas token dispatcher.
    /// @param fees_collector The initial fees collector contract address.
    /// @param gas_oracle The initial gas oracle contract address.
    /// @param gas_oracle_selector The initial gas oracle selector.
    /// @param gas_required The initial required gas amount.
    /// @param participant_required The initial required number of participants.
    /// @param underlying_bridge The dispatcher for the underlying token bridge.
    /// @param yield_bridge The dispatcher for the yield token bridge.
    /// @param deposit_limit Tuple representing the deposit limits (min, max).
    /// @param redeem_limit Tuple representing the redeem limits (min, max).
    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        gas_token: IERC20CamelDispatcher,
        fees_collector: ContractAddress,
        gas_oracle: ContractAddress,
        gas_oracle_selector: felt252,
        gas_required: u256,
        participant_required: u256,
        underlying_bridge: ITokenBridgeDispatcher,
        yield_bridge: ITokenBridgeDispatcher,
        deposit_limit: (u256, u256),
        redeem_limit: (u256, u256)
    ) {
        self.ownable.initializer(owner);
        self
            .batch
            .initializer(
                gas_token,
                owner,
                fees_collector,
                gas_oracle,
                gas_oracle_selector,
                gas_required,
                participant_required
            );
        let underlying_token = underlying_bridge.get_l2_token();
        let yield_token = yield_bridge.get_l2_token();
        self.underlying.write(IERC20CamelDispatcher { contract_address: underlying_token });
        self.yield.write(IERC20CamelDispatcher { contract_address: yield_token });
        self.underlying_bridge.write(underlying_bridge);
        self.yield_bridge.write(yield_bridge);
        self._set_action_limit(Action::Deposit(()), deposit_limit);
        self._set_action_limit(Action::Redeem(()), redeem_limit);
    }


    #[external(v0)]
    impl Pooling4626 of IPooling4626<ContractState> {


        /// @notice Retrieves the amount associated with a given nonce and user address.
        /// @param nonce The unique identifier for a batch of transactions.
        /// @param user The address of the user.
        /// @return A tuple containing two pairs of (u256, bool), each representing an amount and a boolean flag.
        fn user_amount_for_nonce(
            self: @ContractState, nonce: u256, user: ContractAddress
        ) -> ((u256, bool), (u256, bool)) {
            self._user_amount_for_nonce(nonce, user)
        }

        /// @notice Fetches the lists of user addresses associated with a given nonce.
        /// @param nonce The unique identifier for a batch of transactions.
        /// @return Two arrays of ContractAddress, each representing a different set of user addresses.
        fn users_for_nonce(
            self: @ContractState, nonce: u256
        ) -> (Array<ContractAddress>, Array<ContractAddress>) {
            self._users_for_nonce(nonce)
        }


        /// @notice Retrieves the limits set for a particular action.
        /// @param action The specific action to query.
        /// @return A tuple of two u256 values, representing the lower and upper limits for the action.
        fn action_limit(self: @ContractState, action: Action) -> (u256, u256) {
            self.action_limit.read(action)
        }


        /// @notice Allows a user to deposit a specified amount, initiating a transaction batch.
        /// @param underlying_amount The amount of the underlying asset to deposit.
        /// @param participant_pay_amount The amount the participant is required to pay.
        /// @return A tuple containing the transaction nonce and the action type (Deposit).
        fn deposit(
            ref self: ContractState, underlying_amount: u256, participant_pay_amount: u256
        ) -> (u256, Action) {
            let caller = get_caller_address();
            let token = self.underlying.read();
            let this = get_contract_address();
            token.transferFrom(caller, this, underlying_amount);
            let (nonce, is_closed) = self.batch._charge_user(caller, participant_pay_amount);
            self._register_user_action(nonce, Action::Deposit(()), caller, underlying_amount);
            if (is_closed) {
                self._close_batch(nonce);
            }
            self
                .emit(
                    Event::ActionProcessed(
                        ActionProcessed {
                            nonce: nonce,
                            action: Action::Deposit(()),
                            user: caller,
                            amount: underlying_amount
                        }
                    )
                );
            (nonce, Action::Deposit(()))
        }


        /// @notice Allows a user to redeem their yield for a specified amount.
        /// @param yield_amount The amount of yield token to redeem.
        /// @param participant_pay_amount The amount the participant is required to pay.
        /// @return A tuple containing the transaction nonce and the action type (Redeem).
        fn redeem(
            ref self: ContractState, yield_amount: u256, participant_pay_amount: u256
        ) -> (u256, Action) {
            let caller = get_caller_address();
            let token = self.yield.read();
            let this = get_contract_address();
            token.transferFrom(caller, this, yield_amount);
            let (nonce, is_closed) = self.batch._charge_user(caller, participant_pay_amount);
            self._register_user_action(nonce, Action::Redeem(()), caller, yield_amount);
            if (is_closed) {
                self._close_batch(nonce);
            }
            self
                .emit(
                    Event::ActionProcessed(
                        ActionProcessed {
                            nonce: nonce,
                            action: Action::Redeem(()),
                            user: caller,
                            amount: yield_amount
                        }
                    )
                );
            (nonce, Action::Redeem(()))
        }

        /// @notice Processes the harvesting of yields or returns from a batch transaction.
        /// @param nonce The unique identifier of the batch transaction.
        /// @param action The specific action (Deposit or Redeem) being harvested.
        /// @return The amount allocated to the user as a result of the harvest.
        fn harvest(ref self: ContractState, nonce: u256, action: Action) -> u256 {
            let caller = get_caller_address();
            let (amount, harvested) = self.batch_amount.read((nonce, action, caller));
            assert(!amount.is_zero(), Errors::USER_AMOUNT_NUL);
            assert(!harvested, Errors::AMOUNT_HARVESTED);
            self.batch.assert_batch_handled(nonce);
            let total_amount_per_nonce_per_action = self
                ._total_amount_per_nonce_per_action(nonce, action);
            let user_allocation = (amount * PRECISION) / total_amount_per_nonce_per_action;
            let handled_amount = self.batch_handled_amount.read((nonce, action));
            let user_amount = (user_allocation * handled_amount) / PRECISION;
            self
                .emit(
                    Event::HarvestProcessed(
                        HarvestProcessed {
                            nonce: nonce, action: action, user: caller, amount: user_amount
                        }
                    )
                );
            if (action == Action::Deposit(())) {
                let yield_token = self.yield.read();
                yield_token.transfer(caller, user_amount);
                user_amount
            } else {
                let underlying_token = self.underlying.read();
                underlying_token.transfer(caller, user_amount);
                user_amount
            }
        }


        /// @notice Forcefully closes a batch, only accessible by the contract owner.
        /// @param yield_amount The yield amount involved in the batch.
        /// @param participant_pay_amount The amount paid by participants in the batch.
        fn close_batch_force(
            ref self: ContractState, yield_amount: u256, participant_pay_amount: u256
        ) {
            self.ownable.assert_only_owner();
            let nonce = self.batch._close_batch_force();
            let first_address_deposit = self.batch_users.read((nonce, Action::Deposit(()), 0));
            let first_address_redeem = self.batch_users.read((nonce, Action::Deposit(()), 0));
            assert(
                !first_address_deposit.is_zero() && !first_address_redeem.is_zero(),
                Errors::BATCH_EMPTY
            );
            self._close_batch(nonce);
        }

        /// @notice Sets the limit for a specific action, only accessible by the contract owner.
        /// @param action The action for which the limit is being set.
        /// @param limit A tuple of two u256 values, setting the lower and upper limits for the action.
        fn set_action_limit(ref self: ContractState, action: Action, limit: (u256, u256)) {
            self.ownable.assert_only_owner();
            self._set_action_limit(action, limit);
            let (low, high) = limit;
            self
                .emit(
                    Event::LimitUpdated(
                        LimitUpdated {
                            action: action,
                            limit_low: low,
                            limit_high: high
                        }
                    )
                );
        }
    }

    /// @notice Handles the response from an L1 contract interaction, specifically for StarkNet.
    /// @dev This function is marked with the `#[l1_handler]` macro, indicating it handles Layer 1 (Ethereum) responses.
    /// @param from_address The address on L1 that sent the response.
    /// @param nonce The unique identifier for the batch of transactions this response is associated with.
    /// @param underlying_amount The amount of the underlying asset involved in the transaction.
    /// @param yield_amount The amount of yield (or reward) generated from the transaction.
    #[l1_handler]
    fn handle_response(
        ref self: ContractState,
        from_address: felt252,
        nonce: u256,
        underlying_amount: u256,
        yield_amount: u256
    ) {
        let l1_pooling = self.l1_pooling.read();
        assert(from_address == l1_pooling.into(), Errors::WRONG_SENDER);
        self.batch._handle_nonce(nonce);
        self.batch_handled_amount.write((nonce, Action::Deposit(())), yield_amount);
        self.batch_handled_amount.write((nonce, Action::Redeem(())), underlying_amount);
        self
            .emit(
                Event::BatchResponse(
                    BatchResponse {
                        nonce: nonce, total_underlying: underlying_amount, total_yield: yield_amount
                    }
                )
            );
    }


    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        
        /// @notice Internal function to retrieve the amounts associated with a user for a specific nonce.
        /// @param nonce The unique identifier for a batch of transactions.
        /// @param user The address of the user in question.
        /// @return A tuple of two pairs of (u256, bool), representing the amounts for deposit and redeem actions respectively.
        fn _user_amount_for_nonce(
            self: @ContractState, nonce: u256, user: ContractAddress
        ) -> ((u256, bool), (u256, bool)) {
            let deposit_amount = self.batch_amount.read((nonce, Action::Deposit(()), user));
            let redeem_amount = self.batch_amount.read((nonce, Action::Redeem(()), user));
            (deposit_amount, redeem_amount)
        }

        /// @notice Internal function to fetch the lists of user addresses associated with a specific nonce for deposit and redeem actions.
        /// @param nonce The unique identifier for a batch of transactions.
        /// @return Two arrays of ContractAddress, representing the users involved in deposit and redeem actions respectively.
        fn _users_for_nonce(
            self: @ContractState, nonce: u256
        ) -> (Array<ContractAddress>, Array<ContractAddress>) {
            let borrow_users = self._compile_batch_users(nonce, Action::Deposit(()));
            let repay_users = self._compile_batch_users(nonce, Action::Redeem(()));
            (borrow_users, repay_users)
        }

        /// @notice Internal function to compile a list of user addresses for a given action and nonce.
        /// @param nonce The unique identifier for a batch of transactions.
        /// @param action The specific action (Deposit or Redeem) to compile users for.
        /// @return An array of ContractAddress containing the addresses of users involved in the specified action for the given nonce.
        fn _compile_batch_users(
            self: @ContractState, nonce: u256, action: Action
        ) -> Array<ContractAddress> {
            let mut i = 0;
            let mut output = ArrayDefault::default();
            loop {
                let user_address = self.batch_users.read((nonce, action, i));
                if user_address.is_zero() {
                    break ();
                }

                output.append(user_address);
                i += 1;
            };
            output
        }

        /// @notice Internal function to calculate the total amount associated with a specific action for a given nonce.
        /// @param nonce The unique identifier for a batch of transactions.
        /// @param action The action (Deposit or Redeem) for which the total amount is being calculated.
        /// @return A u256 value representing the total amount for the specified action and nonce.
        fn _total_amount_per_nonce_per_action(
            self: @ContractState, nonce: u256, action: Action
        ) -> u256 {
            let mut i = 0;
            let mut accumulator = 0;
            loop {
                let user_address = self.batch_users.read((nonce, action, i));
                if user_address.is_zero() {
                    break ();
                }
                let (amount, _) = self.batch_amount.read((nonce, action, user_address));
                accumulator += amount;
                i += 1;
            };

            accumulator
        }


        /// @notice Internal function to register a user's action along with the amount for a given nonce.
        /// @param nonce The unique identifier for the batch transaction.
        /// @param action The specific action (Deposit or Redeem) the user is performing.
        /// @param user The address of the user performing the action.
        /// @param amount The amount associated with the user's action.
        fn _register_user_action(
            ref self: ContractState,
            nonce: u256,
            action: Action,
            user: ContractAddress,
            amount: u256
        ) {
            let (current_user_action_amount, _) = self.batch_amount.read((nonce, action, user));
            self
                .batch_amount
                .write((nonce, action, user), (current_user_action_amount + amount, false));
            if (current_user_action_amount == 0) {
                let mut i = 0;
                loop {
                    let user_address = self.batch_users.read((nonce, action, i));
                    if user_address.is_zero() {
                        self.batch_users.write((nonce, action, i), user);
                        break ();
                    }
                    i += 1;
                };
            }
        }


        /// @notice Internal function to close a batch and initiate the corresponding L1 transactions.
        /// @param nonce The unique identifier of the batch to be closed.
        /// @dev This function calculates the total amounts for deposit and redeem actions, initiates withdrawals through bridge, and emits a BatchRequest event.
        fn _close_batch(ref self: ContractState, nonce: u256) {
            let underlying_amount = self
                ._total_amount_per_nonce_per_action(nonce, Action::Deposit(()));
            let yield_amount = self._total_amount_per_nonce_per_action(nonce, Action::Redeem(()));
            self._send_message(nonce, underlying_amount, yield_amount);
            let l1_pooling = self.l1_pooling.read().into();

            if (underlying_amount > 0) {
                let token_bridge = self.underlying_bridge.read();
                token_bridge.initiate_withdraw(l1_pooling, underlying_amount);
            }

            if (yield_amount > 0) {
                let token_bridge = self.yield_bridge.read();
                token_bridge.initiate_withdraw(l1_pooling, yield_amount);
            }

            self
                .emit(
                    Event::BatchRequest(
                        BatchRequest {
                            nonce: nonce,
                            total_deposited_amount: underlying_amount,
                            total_redeemed_amount: yield_amount
                        }
                    )
                );
        }

        /// @notice Internal function to send a message to L1 with the batch details.
        /// @param nonce The unique identifier of the batch.
        /// @param underlying_amount The total amount of the underlying asset involved in the batch.
        /// @param yield_amount The total yield amount involved in the batch.
        /// @dev Constructs and sends a message to L1 with the batch details.
        fn _send_message(
            self: @ContractState, nonce: u256, underlying_amount: u256, yield_amount: u256
        ) {
            let mut message_payload: Array<felt252> = ArrayDefault::default();

            message_payload.append(nonce.low.into());
            message_payload.append(nonce.high.into());
            message_payload.append(underlying_amount.low.into());
            message_payload.append(underlying_amount.high.into());
            message_payload.append(yield_amount.low.into());
            message_payload.append(yield_amount.high.into());
            send_message_to_l1_syscall(
                to_address: self.l1_pooling.read().into(), payload: message_payload.span()
            );
        }

        /// @notice Internal function to set the limit for a specific action.
        /// @param action The action for which the limit is being set.
        /// @param limit A tuple of two u256 values, representing the lower and upper limits for the action.
        /// @dev Validates the limits before setting them.
        fn _set_action_limit(ref self: ContractState, action: Action, limit: (u256, u256)) {
            let (limit_low, limit_high) = limit;
            assert(0 < limit_low && limit_low < limit_high, Errors::INVALID_LIMIT);
            self.action_limit.write(action, limit);
        }
    }
}

