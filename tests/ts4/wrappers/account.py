import json

from tonclient.test.helpers import sync_core_client
from tonclient.types import CallSet, ParamsOfEncodeMessageBody, Abi, Signer
from tonos_ts4 import ts4

from utils import random_address


class Account(ts4.BaseContract):

    def __init__(self, contract_name: str = 'Wallet', ctor_params: dict = None):
        if ctor_params is None:
            ctor_params = dict()
        super().__init__(
            contract_name,
            ctor_params,
            nickname='Account',
            override_address=random_address(),
            keypair=ts4.make_keypair(),
        )

    def send_call_set(
            self,
            contract: ts4.BaseContract,
            value: int,
            call_set: CallSet,
            expect_ec: int = 0,
            dispatch: bool = True,
    ):
        encode_params = ParamsOfEncodeMessageBody(
            abi=Abi.Json(json.dumps(contract.abi.json)),
            signer=Signer.NoSigner(),
            call_set=call_set,
            is_internal=True,
        )
        message = sync_core_client.abi.encode_message_body(params=encode_params)
        payload = ts4.Cell(message.body)
        self.send_transaction(contract.address, value, payload=payload, expect_ec=expect_ec, dispatch=dispatch)

    def send_transaction(
            self,
            dest: ts4.Address,
            value: int,
            bounce: bool = True,
            flags: int = 1,
            payload: ts4.Cell = ts4.Cell(ts4.EMPTY_CELL),
            expect_ec: int = 0,
            dispatch: bool = True,
    ):
        self.call_method('sendTransaction', {
            'dest': dest,
            'value': value,
            'bounce': bounce,
            'flags': flags,
            'payload': payload,
        }, private_key=self.private_key_)
        if dispatch:
            ts4.dispatch_one_message(expect_ec=expect_ec)
            ts4.dispatch_messages()
