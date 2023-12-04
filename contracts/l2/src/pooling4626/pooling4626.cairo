#[starknet::contract]
mod Pooling4626 {
    use pooling4626::pooling4626::interface::IPooling4626;
    use openzeppelin::access::ownable::{OwnableComponent};
    use pooling4626::batch::batch::{BatchComponent};
    use pooling4626::token_bridge::interface::{ITokenBridgeDispatcher, ITokenBridgeDispatcherTrait};
    use pooling4626::pooling4626::action::{
            Action, ActionPartialEq, ActionHashTuppleOneImpl, ActionHashTuppleTwoImpl, ActionHashTuppleThreeImpl, DEPOSIT_ACTION, REDEEM_ACTION
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
        get_caller_address, 
        EthAddress, 
        SyscallResult, 
        StorageBaseAddress,
        class_hash::{
            ClassHash, Felt252TryIntoClassHash
        },
        info::{
            get_contract_address, get_block_timestamp
        }, 
        contract_address::{
            ContractAddress, ContractAddressZeroable, Felt252TryIntoContractAddress
        },
        syscalls::{
            send_message_to_l1_syscall, replace_class_syscall
        }
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
        batch_handled_amount: LegacyMap<(u256, Action), u256>
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        BatchEvent: BatchComponent::Event,
        ActionProcessed: ActionProcessed,
        BatchRequest: BatchRequest,
        BatchResponse: BatchResponse
    }


    #[derive(Drop, starknet::Event)]
    struct ActionProcessed {
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

    mod Errors {
        const BATCH_EMPTY: felt252 = 'Batch has no user requests';
        const USER_AMOUNT_NUL: felt252 = 'User amount nul';
        const AMOUNT_HARVESTED: felt252 = 'Amount already harvested';
        const WRONG_SENDER: felt252 = 'Sender is not l1 pooling';
    }

    const PRECISION: u256 = 1000000000000000000;

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
        underlying_bridge : ITokenBridgeDispatcher,
        yield_bridge: ITokenBridgeDispatcher
    ) {
        self.ownable.initializer(owner);
        self.batch.initializer(gas_token, owner, fees_collector, gas_oracle, gas_oracle_selector, gas_required, participant_required);
        let underlying_token = underlying_bridge.get_l2_token();
        let yield_token = yield_bridge.get_l2_token();
        self.underlying.write(IERC20CamelDispatcher{contract_address: underlying_token});
        self.yield.write(IERC20CamelDispatcher{contract_address: yield_token});
        self.underlying_bridge.write(underlying_bridge);
        self.yield_bridge.write(yield_bridge);
    }


    #[external(v0)]
    impl Pooling4626 of IPooling4626<ContractState> {

        fn user_amount_for_nonce(self: @ContractState, nonce: u256, user: ContractAddress) -> ((u256, bool), (u256, bool)) {
            self._user_amount_for_nonce(nonce, user)
        }

        fn users_for_nonce(self: @ContractState, nonce: u256) -> (Array<ContractAddress>, Array<ContractAddress>) {
            self._users_for_nonce(nonce)
        }

        fn deposit(ref self: ContractState, underlying_amount: u256, participant_pay_amount: u256) -> (u256, Action){
            let caller = get_caller_address();
            let token = self.underlying.read();
            let this = get_contract_address();
            token.transferFrom(caller, this, underlying_amount);
            let (nonce, is_closed) = self.batch._charge_user(caller, participant_pay_amount);
            self._register_user_action(nonce, Action::Deposit(()), caller, underlying_amount);
            if(is_closed){
                self._close_batch(nonce);
            }
            (nonce, Action::Deposit(()))
        }

        fn redeem(ref self: ContractState, yield_amount: u256, participant_pay_amount: u256) -> (u256, Action) {
            let caller = get_caller_address();
            let token = self.yield.read();
            let this = get_contract_address();
            token.transferFrom(caller, this, yield_amount);
            let (nonce, is_closed) = self.batch._charge_user(caller, participant_pay_amount);
            self._register_user_action(nonce, Action::Redeem(()), caller, yield_amount);
            if(is_closed){
                self._close_batch(nonce);
            }
            (nonce, Action::Redeem(()))
        }

        fn harvest(ref self: ContractState, nonce: u256, action: Action) -> u256 {
            let caller = get_caller_address();
            let (amount, harvested) = self.batch_amount.read((nonce, action, caller));
            assert(!amount.is_zero(), Errors::USER_AMOUNT_NUL);
            assert(!harvested, Errors::AMOUNT_HARVESTED);
            self.batch.assert_batch_handled(nonce);
            let total_amount_per_nonce_per_action = self._total_amount_per_nonce_per_action(nonce, action);
            let user_allocation = (amount * PRECISION) / total_amount_per_nonce_per_action;
            let handled_amount = self.batch_handled_amount.read((nonce, action));
            let user_amount = (user_allocation * handled_amount) / PRECISION;
            if(action == Action::Deposit(())){
                let yield_token = self.yield.read();
                yield_token.transfer(caller, user_amount);
                user_amount
            } else {
                let underlying_token = self.underlying.read();
                underlying_token.transfer(caller, user_amount);
                user_amount
            }
        }

        fn close_batch_force(ref self: ContractState, yield_amount: u256, participant_pay_amount: u256) {
            self.ownable.assert_only_owner();
            let nonce = self.batch._close_batch_force();
            let first_address_deposit = self.batch_users.read((nonce, Action::Deposit(()), 0));
            let first_address_redeem = self.batch_users.read((nonce, Action::Deposit(()), 0));
            assert(!first_address_deposit.is_zero() && !first_address_redeem.is_zero(), Errors::BATCH_EMPTY);
            self._close_batch(nonce);
        }
    }

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
        self.emit(Event::BatchResponse( BatchResponse {nonce: nonce, total_underlying: underlying_amount, total_yield: yield_amount}));
    }



    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        
        fn _user_amount_for_nonce(self: @ContractState, nonce: u256, user: ContractAddress) -> ((u256, bool), (u256, bool)) {
            let deposit_amount = self.batch_amount.read((nonce, Action::Deposit(()), user));
            let redeem_amount = self.batch_amount.read((nonce, Action::Redeem(()), user));
            (deposit_amount, redeem_amount)
        }

        fn _users_for_nonce(self: @ContractState, nonce: u256) -> (Array<ContractAddress>, Array<ContractAddress>) {
            let borrow_users = self._compile_batch_users(nonce, Action::Deposit(()));
            let repay_users = self._compile_batch_users(nonce, Action::Redeem(()));
            (borrow_users, repay_users)
        }

        fn _compile_batch_users(self: @ContractState, nonce: u256, action: Action) -> Array<ContractAddress> {
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

        fn _total_amount_per_nonce_per_action(self: @ContractState, nonce: u256, action: Action) -> u256 {
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

        fn _register_user_action(ref self: ContractState, nonce: u256, action: Action, user: ContractAddress, amount: u256){
            let (current_user_action_amount, _) = self.batch_amount.read((nonce, action, user));
            self.batch_amount.write((nonce, action, user), (current_user_action_amount + amount, false));
            if(current_user_action_amount == 0){
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

        fn _close_batch(ref self: ContractState, nonce: u256){
            let underlying_amount = self._total_amount_per_nonce_per_action(nonce, Action::Deposit(()));
            let yield_amount = self._total_amount_per_nonce_per_action(nonce, Action::Redeem(()));
            self._send_message(nonce, underlying_amount, yield_amount);
            let l1_pooling = self.l1_pooling.read().into();

            if(underlying_amount > 0){
                let token_bridge = self.underlying_bridge.read();
                token_bridge.initiate_withdraw(l1_pooling, underlying_amount);
            }

            if(yield_amount > 0){
                let token_bridge = self.yield_bridge.read();
                token_bridge.initiate_withdraw(l1_pooling, yield_amount);
            }

            self.emit(Event::BatchRequest( BatchRequest {nonce: nonce, total_deposited_amount: underlying_amount, total_redeemed_amount: yield_amount}));
        }


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
            send_message_to_l1_syscall(to_address: self.l1_pooling.read().into(), payload: message_payload.span());
        }


    }
}


