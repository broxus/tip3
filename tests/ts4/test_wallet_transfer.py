import unittest

from tonclient.types import CallSet
from tonos_ts4 import ts4

from config import DEPLOY_WALLET_VALUE, EXPECTED_WALLET_OWNER_BALANCE, TEST_PAYLOAD
from utils import ZERO_ADDRESS, random_address
from wrappers.deployer import Deployer


class TestWalletTransfer(unittest.TestCase):

    def setUp(self):
        self.deployer = Deployer()
        root_owner = self.deployer.create_account()
        self.root = self.deployer.create_token_root(root_owner, mint_disabled=False)
        self.token_wallet = self.deployer.create_token_wallet(self.root)
        self.root.mint(100, self.token_wallet.owner.address)

    def test_common(self):
        recipient_wallet = self.deployer.create_token_wallet(self.root)
        self.token_wallet.transfer(10, recipient_wallet.owner.address)
        self.token_wallet.check_state(90)
        recipient_wallet.check_state(10)

    def test_new_wallet(self):
        recipient = self.deployer.create_account()
        self.token_wallet.transfer(10, recipient.address, deploy_wallet_value=DEPLOY_WALLET_VALUE)
        recipient_wallet = self.root.wallet_of(recipient)
        self.token_wallet.check_state(90, expected_owner_balance=EXPECTED_WALLET_OWNER_BALANCE - DEPLOY_WALLET_VALUE)
        recipient_wallet.check_state(10, expected_owner_balance=EXPECTED_WALLET_OWNER_BALANCE + DEPLOY_WALLET_VALUE)

    def test_new_wallet_no_deploy(self):
        recipient = self.deployer.create_account()
        self.token_wallet.transfer(10, recipient.address, deploy_wallet_value=0)
        self.assertEqual(self.token_wallet.owner.call_getter('_bounced'), True, 'Wrong callback')
        self.token_wallet.check_state(100)

    def test_deploy_retry(self):
        recipient_wallet = self.deployer.create_token_wallet(self.root)
        self.token_wallet.transfer(10, recipient_wallet.owner.address, deploy_wallet_value=DEPLOY_WALLET_VALUE)
        self.token_wallet.check_state(
            90,
            expected_wallet_balance=2 * DEPLOY_WALLET_VALUE,
            expected_owner_balance=EXPECTED_WALLET_OWNER_BALANCE - DEPLOY_WALLET_VALUE,
        )
        recipient_wallet.check_state(10)

    def test_zero_amount(self):
        recipient_wallet = self.deployer.create_token_wallet(self.root)
        self.token_wallet.transfer(0, recipient_wallet.owner.address, expect_ec=1050)
        self.token_wallet.check_state(100)

    def test_not_enough_balance(self):
        recipient_wallet = self.deployer.create_token_wallet(self.root)
        self.token_wallet.transfer(1000, recipient_wallet.owner.address, expect_ec=1060)
        self.token_wallet.check_state(100)

    def test_remaining_gas_to(self):
        gas_account = self.deployer.create_account()
        recipient_wallet = self.deployer.create_token_wallet(self.root)
        self.token_wallet.transfer(10, recipient_wallet.owner.address, remaining_gas_to=gas_account.address)
        expected_owner_balance = EXPECTED_WALLET_OWNER_BALANCE - ts4.GRAM
        self.token_wallet.check_state(90, expected_owner_balance=expected_owner_balance)
        recipient_wallet.check_state(10)
        self.assertEqual(gas_account.balance, ts4.globals.G_DEFAULT_BALANCE + ts4.GRAM, 'Wrong balance')

    def test_notify(self):
        recipient_wallet = self.deployer.create_token_wallet(self.root)
        self.token_wallet.transfer(
            10,
            recipient_wallet.owner.address,
            notify=True,
            payload=TEST_PAYLOAD,
        )
        expected_transfer_data = {
            'amount': 10,
            'sender': self.token_wallet.owner.address,
            'senderWallet': self.token_wallet.address,
            'remainingGasTo': self.token_wallet.owner.address,
            'payload': TEST_PAYLOAD,
        }
        self.assertEqual(recipient_wallet.owner.call_getter('_transfer'), expected_transfer_data, 'Wrong transfer data')
        self.assertEqual(self.token_wallet.owner.call_getter('_bounced'), False, 'Wrong callback')
        self.token_wallet.check_state(90)
        recipient_wallet.check_state(10)

    def test_transfer_to_wallet(self):
        recipient_wallet = self.deployer.create_token_wallet(self.root)
        call_set = CallSet('transferToWallet', input={
            'amount': 10,
            'recipientTokenWallet': recipient_wallet.address.str(),
            'remainingGasTo': self.token_wallet.owner.address.str(),
            'notify': False,
            'payload': ts4.EMPTY_CELL,
        })
        self.token_wallet.owner.send_call_set(self.token_wallet, value=ts4.GRAM, call_set=call_set)
        self.token_wallet.check_state(90)
        recipient_wallet.check_state(10)

    def test_call_internal_transfer(self):
        recipient_wallet = self.deployer.create_token_wallet(self.root)
        call_set = CallSet('acceptTransfer', input={
            'amount': 10,
            'sender': self.token_wallet.owner.address.str(),
            'remainingGasTo': ZERO_ADDRESS.str(),
            'notify': False,
            'payload': ts4.EMPTY_CELL,
        })
        recipient_wallet.owner.send_call_set(recipient_wallet, value=ts4.GRAM, call_set=call_set, expect_ec=1100)
        self.token_wallet.check_state(100)
        recipient_wallet.check_state(0)

    def test_bounce_callback(self):
        recipient = random_address()
        call_set = CallSet('transferToWallet', input={
            'amount': 10,
            'recipientTokenWallet': recipient.str(),
            'remainingGasTo': ZERO_ADDRESS.str(),
            'notify': False,
            'payload': ts4.EMPTY_CELL,
        })
        self.token_wallet.owner.send_call_set(self.token_wallet, value=ts4.GRAM, call_set=call_set)
        self.assertEqual(self.token_wallet.owner.call_getter('_bounced'), True, 'Wrong callback')
        self.assertEqual(self.token_wallet.owner.call_getter('_bouncedAmount'), 10, 'Wrong callback')
        self.assertEqual(self.token_wallet.owner.call_getter('_bouncedFrom'), recipient, 'Wrong callback')
        self.token_wallet.check_state(100)
