from tonclient.types import CallSet
from tonos_ts4 import ts4

from utils import ZERO_ADDRESS
from wrappers.account import Account
from wrappers.token_wallet import TokenWallet


class TokenRoot(ts4.BaseContract):

    def __init__(self, address: ts4.Address, owner: Account):
        super().__init__('TokenRoot', {}, nickname='TokenRoot', address=address)
        self.owner = owner

    def call_responsible(self, name: str, params: dict = None):
        if params is None:
            params = dict()
        params['answerId'] = 0
        return self.call_getter(name, params)

    def total_supply(self) -> int:
        return self.call_responsible('totalSupply')

    def wallet_of(self, wallet_owner: Account) -> TokenWallet:
        wallet_address = self.call_responsible('walletOf', {'walletOwner': wallet_owner.address})
        return TokenWallet(wallet_address, wallet_owner)

    def mint(
            self,
            amount: int,
            recipient: ts4.Address,
            deploy_wallet_value: int = 0,
            remaining_gas_to: ts4.Address = ZERO_ADDRESS,
            notify: bool = False,
            payload: ts4.Cell = ts4.Cell(ts4.EMPTY_CELL),
            expect_ec: int = 0,
    ):
        if remaining_gas_to == ZERO_ADDRESS:
            remaining_gas_to = self.owner.address
        call_set = CallSet('mint', input={
            'amount': amount,
            'recipient': recipient.str(),
            'deployWalletValue': deploy_wallet_value,
            'remainingGasTo': remaining_gas_to.str(),
            'notify': notify,
            'payload': payload.raw_,
        })
        self.owner.send_call_set(self, value=ts4.GRAM, call_set=call_set, expect_ec=expect_ec)

    def burn_tokens(
            self,
            amount: int,
            wallet_owner: ts4.Address,
            remaining_gas_to: ts4.Address = ZERO_ADDRESS,
            callback_to: ts4.Address = ZERO_ADDRESS,
            payload: ts4.Cell = ts4.Cell(ts4.EMPTY_CELL),
            expect_ec: int = 0,
            dispatch: bool = True,
    ):
        if remaining_gas_to == ZERO_ADDRESS:
            remaining_gas_to = self.owner.address
        call_set = CallSet('burnTokens', input={
            'amount': amount,
            'walletOwner': wallet_owner.str(),
            'remainingGasTo': remaining_gas_to.str(),
            'callbackTo': callback_to.str(),
            'payload': payload.raw_,
        })
        self.owner.send_call_set(self, value=ts4.GRAM, call_set=call_set, expect_ec=expect_ec, dispatch=dispatch)

    def set_burn_paused(self, paused: bool, dispatch: bool = True):
        call_set = CallSet('setBurnPaused', input={'paused': paused, 'answerId': 0})
        self.owner.send_call_set(self, value=ts4.GRAM, call_set=call_set, dispatch=dispatch)
