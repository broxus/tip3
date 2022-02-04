import unittest

from tonclient.types import CallSet
from tonos_ts4 import ts4

from config import DEPLOY_WALLET_VALUE, TEST_PAYLOAD
from wrappers.deployer import Deployer


class TestMint(unittest.TestCase):

    def setUp(self):
        self.deployer = Deployer()
        root_owner = self.deployer.create_account()
        self.root = self.deployer.create_token_root(root_owner, mint_disabled=False)

    def test_common(self):
        token_wallet = self.deployer.create_token_wallet(self.root)
        self.root.mint(100, token_wallet.owner.address)
        self.assertEqual(self.root.total_supply(), 100, 'Wrong total supply')
        token_wallet.check_state(100)

    def test_with_deploy(self):
        account = self.deployer.create_account()
        self.root.mint(100, account.address, deploy_wallet_value=DEPLOY_WALLET_VALUE)
        self.assertEqual(self.root.total_supply(), 100, 'Wrong total supply')
        token_wallet = self.root.wallet_of(account)
        token_wallet.check_state(100, expected_owner_balance=ts4.globals.G_DEFAULT_BALANCE)

    def test_with_deploy_no_deploy_value(self):
        account = self.deployer.create_account()
        self.root.mint(100, account.address, deploy_wallet_value=0)
        with self.assertRaisesRegex(RuntimeError, 'Unable to set ABI for non-existent address 0:.{64}'):
            self.root.wallet_of(account)  # Contract doesnt exist
        self.assertEqual(self.root.total_supply(), 0, 'Wrong total supply')

    def test_zero_amount(self):
        token_wallet = self.deployer.create_token_wallet(self.root)
        self.root.mint(0, token_wallet.owner.address, expect_ec=1050)
        token_wallet.check_state(0)
        self.assertEqual(self.root.total_supply(), 0, 'Wrong total supply')

    def test_remaining_gas_to(self):
        gas_account = self.deployer.create_account()
        token_wallet = self.deployer.create_token_wallet(self.root)
        self.root.mint(100, token_wallet.owner.address, remaining_gas_to=gas_account.address)
        self.assertEqual(self.root.total_supply(), 100, 'Wrong total supply')
        self.assertEqual(gas_account.balance, ts4.globals.G_DEFAULT_BALANCE + ts4.GRAM, 'Wrong balance')
        token_wallet.check_state(100)

    def test_callback(self):
        token_wallet = self.deployer.create_token_wallet(self.root)
        self.root.mint(100, token_wallet.owner.address, notify=True, payload=TEST_PAYLOAD)
        self.assertEqual(self.root.total_supply(), 100, 'Wrong total supply')
        self.assertEqual(token_wallet.owner.call_getter('_minted'), True, 'Wrong callback')
        self.assertEqual(token_wallet.owner.call_getter('_mintedAmount'), 100, 'Wrong callback')
        self.assertEqual(token_wallet.owner.call_getter('_mintedPayload'), TEST_PAYLOAD, 'Wrong callback')
        token_wallet.check_state(100)

    def test_disable(self):
        self.assertEqual(self.root.call_responsible('mintDisabled'), False, 'Wrong `mintDisabled` value')
        call_set = CallSet('disableMint', input={'answerId': 0})
        self.root.owner.send_call_set(self.root, value=ts4.GRAM, call_set=call_set)
        self.assertEqual(self.root.call_responsible('mintDisabled'), True, 'Wrong `mintDisabled` value')
        # Check if mint is really disabled
        token_wallet = self.deployer.create_token_wallet(self.root)
        self.root.mint(100, token_wallet.owner.address, expect_ec=2100)
        self.assertEqual(self.root.total_supply(), 0, 'Wrong total supply')
        token_wallet.check_state(0)

    def test_init_disabled(self):
        root_owner = self.deployer.create_account()
        root = self.deployer.create_token_root(root_owner, mint_disabled=True)
        token_wallet = self.deployer.create_token_wallet(self.root)
        root.mint(100, token_wallet.owner.address, expect_ec=2100)
        self.assertEqual(root.total_supply(), 0, 'Wrong total supply')
        token_wallet.check_state(0)
