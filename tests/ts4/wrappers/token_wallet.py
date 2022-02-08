from tonclient.types import CallSet
from tonos_ts4 import ts4

from config import TARGET_WALLET_BALANCE, EXPECTED_WALLET_OWNER_BALANCE
from utils import ZERO_ADDRESS
from wrappers.account import Account


class TokenWallet(ts4.BaseContract):

    def __init__(self, address: ts4.Address, owner: Account):
        super().__init__('TokenWallet', {}, nickname='TokenWallet', address=address)
        self.owner = owner

    @property
    def token_balance(self) -> int:
        return self.call_getter('balance', {'answerId': 0})

    def call_responsible(self, name: str, params: dict = None):
        if params is None:
            params = dict()
        params['answerId'] = 0
        return self.call_getter(name, params)

    def transfer(
            self,
            amount: int,
            recipient: ts4.Address,
            deploy_wallet_value: int = 0,
            remaining_gas_to: ts4.Address = ZERO_ADDRESS,
            notify: bool = False,
            payload: ts4.Cell = ts4.Cell(ts4.EMPTY_CELL),
            expect_ec: int = 0,
            dispatch: bool = True,
    ):
        if remaining_gas_to == ZERO_ADDRESS:
            remaining_gas_to = self.owner.address
        call_set = CallSet('transfer', input={
            'amount': amount,
            'recipient': recipient.str(),
            'deployWalletValue': deploy_wallet_value,
            'remainingGasTo': remaining_gas_to.str(),
            'notify': notify,
            'payload': payload.raw_,
        })
        self.owner.send_call_set(self, value=ts4.GRAM, call_set=call_set, expect_ec=expect_ec, dispatch=dispatch)

    def set_callback(self, callback: ts4.Address, only_notifiable_transfers: bool):
        call_set = CallSet('setCallback', input={
            'callback': callback.str(),
            'onlyNotifiableTransfers': only_notifiable_transfers,
        })
        self.owner.send_call_set(self, value=ts4.GRAM, call_set=call_set)

    def burn(
            self,
            amount: int,
            remaining_gas_to: ts4.Address = ZERO_ADDRESS,
            callback_to: ts4.Address = ZERO_ADDRESS,
            payload: ts4.Cell = ts4.Cell(ts4.EMPTY_CELL),
            expect_ec: int = 0,
            dispatch: bool = True,
    ):
        if remaining_gas_to == ZERO_ADDRESS:
            remaining_gas_to = self.owner.address
        call_set = CallSet('burn', input={
            'amount': amount,
            'remainingGasTo': remaining_gas_to.str(),
            'callbackTo': callback_to.str(),
            'payload': payload.raw_,
        })
        self.owner.send_call_set(self, value=ts4.GRAM, call_set=call_set, expect_ec=expect_ec, dispatch=dispatch)

    def check_state(
            self,
            expected_token_balance: int,
            expected_wallet_balance: int = TARGET_WALLET_BALANCE,
            expected_owner_balance: int = EXPECTED_WALLET_OWNER_BALANCE,
    ):
        assert self.token_balance == expected_token_balance, f'Wrong token balance {self.token_balance}'
        assert self.balance == expected_wallet_balance, f'Wrong balance {self.balance} {expected_wallet_balance}'
        assert self.owner.balance == expected_owner_balance, f'Wrong balance {self.owner.balance}'
