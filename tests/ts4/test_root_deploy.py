import unittest

from tonos_ts4 import ts4

from config import NAME, SYMBOL, DECIMALS
from utils import ZERO_ADDRESS, check_supports_interfaces
from wrappers.deployer import Deployer


class TestRootDeploy(unittest.TestCase):

    def setUp(self):
        self.deployer = Deployer()
        self.root_owner = self.deployer.create_account()

    def test_base(self):
        root = self.deployer.create_token_root(self.root_owner)
        expected_wallet_code = ts4.load_code_cell('TokenWallet')
        self.assertEqual(root.call_responsible('name'), NAME, 'Wrong name')
        self.assertEqual(root.call_responsible('symbol'), SYMBOL, 'Wrong symbol')
        self.assertEqual(root.call_responsible('decimals'), DECIMALS, 'Wrong decimals')
        self.assertEqual(root.call_responsible('rootOwner'), root.owner.address, 'Wrong owner')
        self.assertEqual(root.call_responsible('walletCode'), expected_wallet_code, 'Wrong wallet code')
        self.assertEqual(root.total_supply(), 0, 'Wrong total supply')
        self.assertEqual(root.call_responsible('mintDisabled'), True, 'Wrong `mintDisabled` value')
        self.assertEqual(root.call_responsible('burnByRootDisabled'), True, 'Wrong `burnDisabled` value')
        self.assertEqual(root.call_responsible('burnPaused'), False, 'Wrong `burnPaused` value')
        interface_ids = (0x3204ec29, 0x4371d8ed, 0x0b1fd263, 0x18f7cce4, 0x0095b2fa, 0x45c92654, 0x1df385c6)
        check_supports_interfaces(root, interface_ids)
        self.assertEqual(root.balance, 2 * ts4.GRAM, 'Wrong root balance')

    def test_initial_supply(self):
        total_supply = 100
        initial_supply_account = self.deployer.create_account()
        root = self.deployer.create_token_root(
            self.root_owner,
            initial_supply_to=initial_supply_account.address,
            initial_supply=total_supply,
        )
        token_wallet = root.wallet_of(initial_supply_account)
        self.assertEqual(root.total_supply(), total_supply, 'Wrong total supply')
        self.assertEqual(token_wallet.token_balance, total_supply, 'Wrong initial supply to balance')

    def test_initial_supply_zero_address(self):
        total_supply = 100
        root = self.deployer.create_token_root(
            self.root_owner,
            initial_supply_to=ZERO_ADDRESS,
            initial_supply=total_supply,
        )
        self.assertEqual(root.total_supply(), 0, 'Wrong total supply')
