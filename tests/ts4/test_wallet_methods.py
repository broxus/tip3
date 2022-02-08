import unittest

from tonclient.types import CallSet
from tonos_ts4 import ts4

from utils import check_supports_interfaces
from wrappers.deployer import Deployer


class TestWalletMethods(unittest.TestCase):

    def setUp(self):
        self.deployer = Deployer()
        root_owner = self.deployer.create_account()
        self.root = self.deployer.create_token_root(root_owner, mint_disabled=False)
        self.token_wallet = self.deployer.create_token_wallet(self.root)

    def test_base(self):
        expected_wallet_code = ts4.load_code_cell('TokenWallet')
        self.assertEqual(self.token_wallet.call_responsible('root'), self.root.address, 'Wrong root')
        self.assertEqual(self.token_wallet.call_responsible('owner'), self.token_wallet.owner.address, 'Wrong owner')
        self.assertEqual(self.token_wallet.call_responsible('walletCode'), expected_wallet_code, 'Wrong wallet code')
        self.assertEqual(self.token_wallet.token_balance, 0, 'Wrong token balance')  # .balance() method
        self.assertEqual(
            self.token_wallet.owner.call_getter('_wallet'),
            self.token_wallet.address,
            'Wrong token wallet address',
        )
        interface_ids = (0x0f0258aa, 0x3204ec29, 0x4f479fa3, 0x2a4ac43e, 0x562548ad, 0x0c2ff20d, 0x0f0258aa)
        check_supports_interfaces(self.token_wallet, interface_ids)
        self.token_wallet.check_state(0)

    def test_destroy(self):
        call_set = CallSet('destroy', input={'remainingGasTo': self.token_wallet.owner.address.str()})
        self.token_wallet.owner.send_call_set(self.token_wallet, value=ts4.GRAM, call_set=call_set)
        self.assertEqual(self.token_wallet.balance, None, 'Wrong balance')  # Contract doesnt exist

    def test_destroy_not_owner(self):
        account = self.deployer.create_account()
        call_set = CallSet('destroy', input={'remainingGasTo': account.address.str()})
        account.send_call_set(self.token_wallet, value=ts4.GRAM, call_set=call_set, expect_ec=1000)
        self.token_wallet.check_state(0)

    def test_destroy_with_balance(self):
        self.root.mint(1, self.token_wallet.owner.address)
        call_set = CallSet('destroy', input={'remainingGasTo': self.token_wallet.owner.address.str()})
        self.token_wallet.owner.send_call_set(self.token_wallet, value=ts4.GRAM, call_set=call_set, expect_ec=1070)
        self.token_wallet.check_state(1)
