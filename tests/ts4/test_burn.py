import unittest

from tonclient.types import CallSet
from tonos_ts4 import ts4

from config import EXPECTED_WALLET_OWNER_BALANCE, TEST_PAYLOAD
from utils import dispatch_with_exception
from wrappers.deployer import Deployer


class TestBurn(unittest.TestCase):

    def setUp(self):
        self.deployer = Deployer()
        root_owner = self.deployer.create_account()
        self.root = self.deployer.create_token_root(root_owner, mint_disabled=False, burn_by_root_disabled=False)
        self.token_wallet = self.deployer.create_token_wallet(self.root)
        self.root.mint(100, self.token_wallet.owner.address)

    def test_wallet(self):
        self.token_wallet.burn(10)
        self.token_wallet.check_state(90)
        self.assertEqual(self.root.total_supply(), 90, 'Wrong total supply')

    def test_wallet_zero_amount(self):
        self.token_wallet.burn(0, expect_ec=1050)
        self.token_wallet.check_state(100)
        self.assertEqual(self.root.total_supply(), 100, 'Wrong total supply')

    def test_wallet_not_enough_balance(self):
        self.token_wallet.burn(1000, expect_ec=1060)
        self.token_wallet.check_state(100)
        self.assertEqual(self.root.total_supply(), 100, 'Wrong total supply')

    def test_wallet_pause(self):
        self.assertEqual(self.root.call_responsible('burnPaused'), False, 'Wrong `burnPaused` value')
        self.root.set_burn_paused(True)
        self.token_wallet.burn(10, dispatch=False)
        dispatch_with_exception(expect_ec=2200, expect_index=1)
        self._assert_burn_bounced_callback()
        self.token_wallet.check_state(100)

    def test_wallet_callback(self):
        self.token_wallet.burn(10, callback_to=self.token_wallet.owner.address, payload=TEST_PAYLOAD)
        self._assert_burn_callback(TEST_PAYLOAD)

    def test_root(self):
        self.root.burn_tokens(10, self.token_wallet.owner.address)
        self.token_wallet.check_state(90)
        self.assertEqual(self.root.total_supply(), 90, 'Wrong total supply')

    def test_root_zero_amount(self):
        self.root.burn_tokens(0, self.token_wallet.owner.address, expect_ec=1050)
        self.token_wallet.check_state(100)
        self.assertEqual(self.root.total_supply(), 100, 'Wrong total supply')

    def test_root_not_enough_balance(self):
        self.root.burn_tokens(1000, self.token_wallet.owner.address, dispatch=False)
        dispatch_with_exception(expect_ec=1060, expect_index=1)
        self.token_wallet.check_state(100)
        self.assertEqual(self.root.total_supply(), 100, 'Wrong total supply')

    def test_root_disable(self):
        self.assertEqual(self.root.call_responsible('burnByRootDisabled'), False, 'Wrong `burnDisabled` value')
        call_set = CallSet('disableBurnByRoot', input={'answerId': 0})
        self.root.owner.send_call_set(self.root, value=ts4.GRAM, call_set=call_set)
        self.assertEqual(self.root.call_responsible('burnByRootDisabled'), True, 'Wrong `burnDisabled` value')
        # Check if burn is really disabled
        self.root.burn_tokens(10, self.token_wallet.owner.address, expect_ec=2210)
        self.assertEqual(self.root.total_supply(), 100, 'Wrong total supply')
        self.token_wallet.check_state(100)

    def test_root_callback(self):
        self.root.burn_tokens(
            10,
            self.token_wallet.owner.address,
            callback_to=self.token_wallet.owner.address,
            payload=TEST_PAYLOAD,
        )
        self._assert_burn_callback(TEST_PAYLOAD)

    def test_root_burn_and_pause(self):
        """
        Case when root starts burning, but paused it in the same time
        burnTokens -> setBurnPaused -> burnByRoot -> tokensBurned -> onBounceTokensBurn
        """
        self.root.burn_tokens(10, self.token_wallet.owner.address, dispatch=False)
        self.root.set_burn_paused(True, dispatch=False)
        dispatch_with_exception(expect_ec=2200, expect_index=4)
        self._assert_burn_bounced_callback()
        self.token_wallet.check_state(100, expected_owner_balance=EXPECTED_WALLET_OWNER_BALANCE + ts4.GRAM)

    def _assert_burn_callback(self, payload: ts4.Cell):
        self.assertEqual(self.root.total_supply(), 90, 'Wrong total supply')
        self.assertEqual(self.token_wallet.owner.call_getter('_burned'), True, 'Wrong callback')
        self.assertEqual(self.token_wallet.owner.call_getter('_burnedAmount'), 10, 'Wrong callback')
        self.assertEqual(self.token_wallet.owner.call_getter('_burnedPayload'), payload, 'Wrong callback')
        self.assertEqual(self.token_wallet.owner.call_getter('_burnedBounced'), False, 'Wrong callback')
        self.assertEqual(self.root.call_responsible('burnPaused'), False, 'Wrong `burnPaused` value')
        self.token_wallet.check_state(90)

    def _assert_burn_bounced_callback(self):
        self.assertEqual(self.token_wallet.owner.call_getter('_burnedBounced'), True, 'Wrong callback')
        self.assertEqual(self.token_wallet.owner.call_getter('_burnedAmount'), 10, 'Wrong callback')
        self.assertEqual(self.root.total_supply(), 100, 'Wrong total supply')
        self.assertEqual(self.root.call_responsible('burnPaused'), True, 'Wrong `burnPaused` value')
