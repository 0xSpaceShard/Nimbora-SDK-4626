use traits::{Into, TryInto, PartialEq};
use option::OptionTrait;
use starknet::{StorageBaseAddress, SyscallResult, storage_access::Store, ContractAddress};


const SEND_FROM_CALLER_ACTION: felt252 = 0;
const SEND_FROM_CONTRACT_ACTION: felt252 = 1;
const DEPOSIT_ACTION: felt252 = 0;
const REDEEM_ACTION: felt252 = 1;

const FELT_TO_ACTION_FAILED: felt252 = 'FELT_TO_ACTION_FAILED';


#[derive(Drop, Copy, Serde)]
enum ActionSend {
    SendFromCaller: (),
    SendFromContract: (),
}

#[derive(Drop, Copy, Serde)]
enum Action {
    Deposit: (),
    Redeem: (),
}

impl ActionSendPartialEq of PartialEq<ActionSend> {
    #[inline(always)]
    fn eq(lhs: @ActionSend, rhs: @ActionSend) -> bool {
        let lhs_snap: ActionSend = *lhs;
        let rhs_snap: ActionSend = *rhs;
        
        let val: felt252 = lhs_snap.into();
        val == rhs_snap.into()
    }
    #[inline(always)]
    fn ne(lhs: @ActionSend, rhs: @ActionSend) -> bool {
        let lhs_snap: ActionSend = *lhs;
        let rhs_snap: ActionSend = *rhs;
        
        let val: felt252 = lhs_snap.into();
        val != rhs_snap.into()
    }
}

impl BoolIntoActionSendImpl of Into<bool, ActionSend> {
    fn into(self: bool) -> ActionSend {
        if self {
            ActionSend::SendFromContract(())
        } else {
            ActionSend::SendFromCaller(())
        }
    }
}

impl Felt252ITryIntoActionSendImpl of TryInto<felt252, ActionSend> {
    fn try_into(self: felt252) -> Option<ActionSend> {
        if self == SEND_FROM_CALLER_ACTION {
            Option::Some(ActionSend::SendFromCaller(()))
        } else if self == SEND_FROM_CONTRACT_ACTION {
            Option::Some(ActionSend::SendFromContract(()))
        } else {
            Option::None(())
        }
    }
}

impl ActionSendIntoFelt252 of Into<ActionSend, felt252> {
    fn into(self: ActionSend) -> felt252 {
        match self {
            ActionSend::SendFromCaller(_) => SEND_FROM_CALLER_ACTION,
            ActionSend::SendFromContract(_) => SEND_FROM_CONTRACT_ACTION,
        }
    }
}


impl ActionPartialEq of PartialEq<Action> {
    #[inline(always)]
    fn eq(lhs: @Action, rhs: @Action) -> bool {
        let lhs_snap: Action = *lhs;
        let rhs_snap: Action = *rhs;
        
        let val: felt252 = lhs_snap.into();
        val == rhs_snap.into()
    }
    #[inline(always)]
    fn ne(lhs: @Action, rhs: @Action) -> bool {
        let lhs_snap: Action = *lhs;
        let rhs_snap: Action = *rhs;
        
        let val: felt252 = lhs_snap.into();
        val != rhs_snap.into()
    }
}


impl BoolIntoActionImpl of Into<bool, Action> {
    fn into(self: bool) -> Action {
        if self {
            Action::Deposit(())
        } else {
            Action::Redeem(())
        }
    }
}

impl Felt252ITryIntoActionImpl of TryInto<felt252, Action> {
    fn try_into(self: felt252) -> Option<Action> {
        if self == DEPOSIT_ACTION {
            Option::Some(Action::Deposit(()))
        } else if self == REDEEM_ACTION {
            Option::Some(Action::Redeem(()))
        } else {
            Option::None(())
        }
    }
}

impl ActionIntoFelt252 of Into<Action, felt252> {
    fn into(self: Action) -> felt252 {
        match self {
            Action::Deposit(_) => DEPOSIT_ACTION,
            Action::Redeem(_) => REDEEM_ACTION,
        }
    }
}


impl ActionHashTuppleOneImpl of hash::LegacyHash::<(u256, Action, felt252)> {
    fn hash(state: felt252, value: (u256, Action, felt252)) -> felt252 {
        let (x, y, z) = value;
        let y_felt = y.into();
        hash::LegacyHash::<(u256, felt252, felt252)>::hash(state, (x, y_felt, z))
    }
}

impl ActionHashTuppleTwoImpl of hash::LegacyHash::<(u256, Action, ContractAddress)> {
    fn hash(state: felt252, value: (u256, Action, ContractAddress)) -> felt252 {
        let (x, y, z) = value;
        let y_felt = y.into();
        hash::LegacyHash::<(u256, felt252, ContractAddress)>::hash(state, (x, y_felt, z))
    }
}

impl ActionHashTuppleThreeImpl of hash::LegacyHash::<(u256, Action)> {
    fn hash(state: felt252, value: (u256, Action)) -> felt252 {
        let (x, y) = value;
        let y_felt = y.into();
        hash::LegacyHash::<(u256, felt252)>::hash(state, (x, y_felt))
    }
}



