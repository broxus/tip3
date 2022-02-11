import random
import string

from tonos_ts4 import ts4

ZERO_ADDRESS = ts4.Address.zero_addr()
HEXDIGITS = string.digits + 'abcdef'


def random_address() -> ts4.Address:
    address = '0:' + ''.join(random.choices(HEXDIGITS, k=64))
    return ts4.Address(address)


def dispatch_with_exception(expect_ec: int, expect_index: int = 0):
    for _ in range(expect_index):
        ts4.dispatch_one_message()
    ts4.dispatch_one_message(expect_ec=expect_ec)
    ts4.dispatch_messages()


def check_supports_interfaces(contract: ts4.BaseContract, interface_ids: tuple):
    for interface_id in interface_ids:
        actual = contract.call_getter('supportsInterface', {
            'interfaceID': interface_id,
            'answerId': 0,
        })
        assert actual is True, f'Interface {interface_id:x} is not supported'
