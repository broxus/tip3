import unittest

from tonclient.types import CallSet
from tonos_ts4 import ts4

from config import DEPLOY_WALLET_VALUE, TARGET_ROOT_BALANCE, TEST_PAYLOAD, TEST_PAYLOAD_2
from wrappers.deployer import Deployer


class TestRootMethods(unittest.TestCase):

    def setUp(self):
        self.deployer = Deployer()
        root_owner = self.deployer.create_account()
        self.root = self.deployer.create_token_root(root_owner)

    def test_deploy_wallet(self):
        token_wallet = self.deployer.create_token_wallet(self.root)
        self.assertEqual(token_wallet.token_balance, 0, 'Wrong token balance')
        self.assertEqual(token_wallet.balance, DEPLOY_WALLET_VALUE, 'Wrong balance')
        self.assertEqual(token_wallet.owner.call_getter('_wallet'), token_wallet.address, 'Wrong token wallet address')

    def test_send_supply_gas(self):
        # transfer supply value
        additional_value = 10 * ts4.GRAM
        account = self.deployer.create_account()
        account.send_transaction(self.root.address, value=additional_value, bounce=False)
        account_balance_before = account.balance
        root_balance_before = self.root.balance
        # get supply value
        call_set = CallSet('sendSurplusGas', input={'to': account.address.str()})
        self.root.owner.send_call_set(self.root, value=ts4.GRAM, call_set=call_set)
        account_balance_after = account.balance
        root_balance_after = self.root.balance
        self.assertEqual(
            account_balance_after - account_balance_before,
            root_balance_before - root_balance_after + ts4.GRAM,  # +1 ton from calling sendSurplusGas
            'Wrong supply value',
        )
        self.assertEqual(self.root.balance, TARGET_ROOT_BALANCE, 'Wrong root balance')

    def test_send_supply_gas_not_owner(self):
        token_wallet = self.deployer.create_token_wallet(self.root)
        call_set = CallSet('sendSurplusGas', input={'to': token_wallet.address.str()})
        token_wallet.owner.send_call_set(self.root, value=ts4.GRAM, call_set=call_set, expect_ec=1000)

    def test_transfer_ownership(self):
        self.root_owner = self.deployer.create_account(contract_name='TestRootTransferCallback')
        self.root = self.deployer.create_token_root(self.root_owner)
        self.root_owner.call_method('setRoot', {'root': self.root.address})
        callback_account = self.deployer.create_account(contract_name='TestRootTransferCallback')
        callback_account.call_method('setRoot', {'root': self.root.address})
        new_root_owner = self.deployer.create_account()

        callback_account_value = int(0.5 * ts4.GRAM)
        call_set = CallSet('transferOwnership', input={
            'newOwner': new_root_owner.address.str(),
            'remainingGasTo': self.root_owner.address.str(),
            'callbacks': {
                callback_account.address.str(): {
                    'value': callback_account_value,
                    'payload': TEST_PAYLOAD.raw_,
                },
                self.root_owner.address.str(): {
                    'value': 10000 * ts4.GRAM,
                    'payload': TEST_PAYLOAD_2.raw_,
                },
            },
        })
        self.root_owner.send_call_set(self.root, value=2 * ts4.GRAM, call_set=call_set)

        callback_base = {
            'newOwner': new_root_owner.address,
            'oldOwner': self.root_owner.address,
            'remainingGasTo': self.root_owner.address,
        }
        expected_callback_1 = {'payload': TEST_PAYLOAD, **callback_base}
        expected_callback_2 = {'payload': TEST_PAYLOAD_2, **callback_base}
        self.assertEqual(new_root_owner.address, self.root.call_responsible('rootOwner'), 'Wrong root owner')
        self.assertEqual(callback_account.call_getter('_callback'), expected_callback_1, 'Wrong callback')
        self.assertEqual(self.root_owner.call_getter('_callback'), expected_callback_2, 'Wrong callback')
        self.assertEqual(self.root_owner.balance, ts4.g.G_DEFAULT_BALANCE - callback_account_value, 'Wrong balance')
        self.assertEqual(callback_account.balance, ts4.g.G_DEFAULT_BALANCE + callback_account_value, 'Wrong balance')
        self.assertEqual(new_root_owner.balance, ts4.g.G_DEFAULT_BALANCE, 'Wrong balance')

    def test_transfer_ownership_not_owner(self):
        account = self.deployer.create_account()
        call_set = CallSet('transferOwnership', input={
            'newOwner': account.address.str(),
            'remainingGasTo': account.address.str(),
            'callbacks': {},
        })
        account.send_call_set(self.root, value=ts4.GRAM, call_set=call_set, expect_ec=1000)
