import unittest

from tonclient.types import CallSet
from tonos_ts4 import ts4
from tonos_ts4.abi import Abi

from config import DEPLOY_WALLET_VALUE
from wrappers.deployer import Deployer
from wrappers.token_wallet import TokenWallet


class TestUpgradeable(unittest.TestCase):

    def setUp(self):
        self.deployer = Deployer()
        root_owner = self.deployer.create_account()
        self.root = self.deployer.create_token_root(root_owner, mint_disabled=False, upgradeable=True)
        self._sync_ts4_abi(self.root, 'TokenRootUpgradeable')

    def test_root_upgrade(self):
        self._update_root('TestTokenRootUpgradeableV2')
        self.assertEqual(self.root.call_responsible('onlyInV2'), 'Some method in root v2', 'Wrong updating')

    def test_wallet_upgrade(self):
        token_wallet = self._create_wallet()
        self.assertEqual(self.root.call_responsible('walletVersion'), 1, 'Wrong version')
        self.assertEqual(token_wallet.call_responsible('version'), 1, 'Wrong version')
        self._set_wallet_code('TestTokenWalletUpgradeableV2')
        self.assertEqual(self.root.call_responsible('walletVersion'), 2, 'Wrong version')
        self._update_wallet(token_wallet, 'TestTokenWalletUpgradeableV2')
        self.assertEqual(token_wallet.call_responsible('version'), 2, 'Wrong version')
        self.assertEqual(token_wallet.call_responsible('onlyInV2'), 'Some method in wallet v2', 'Wrong updating')

    def test_wallet_no_upgrade(self):
        token_wallet = self._create_wallet()
        self.assertEqual(self.root.call_responsible('walletVersion'), 1, 'Wrong version')
        self.assertEqual(token_wallet.call_responsible('version'), 1, 'Wrong version')
        self._update_wallet(token_wallet)
        self.assertEqual(self.root.call_responsible('walletVersion'), 1, 'Wrong version')
        self.assertEqual(token_wallet.call_responsible('version'), 1, 'Wrong version')

    @unittest.skip('Bug with `onDeployRetry` in ts4 | Tested in mainnet')
    def test_deploy_retry(self):
        token_wallet_1 = self._create_wallet()
        token_wallet_2 = self._create_wallet()
        self.root.mint(100, token_wallet_1.owner.address)
        token_wallet_1.transfer(10, token_wallet_2.owner.address, deploy_wallet_value=DEPLOY_WALLET_VALUE)
        token_wallet_2.check_state(90)
        token_wallet_2.check_state(10)

    def test_different_versions(self):
        token_wallet_1 = self._create_wallet()
        token_wallet_2 = self._create_wallet()
        self._set_wallet_code('TestTokenWalletUpgradeableV2')
        self._update_wallet(token_wallet_1, 'TestTokenWalletUpgradeableV2')
        version_wallet_1 = token_wallet_1.call_responsible('version')
        version_wallet_2 = token_wallet_2.call_responsible('version')
        self.assertEqual(version_wallet_1, version_wallet_2 + 1, 'Wrong version')
        self.root.mint(100, token_wallet_1.owner.address)
        token_wallet_1.transfer(10, token_wallet_2.owner.address)
        token_wallet_1.check_state(90)
        token_wallet_2.check_state(10)

    def test_upgrades_not_owner(self):
        account = self.deployer.create_account()
        new_code = ts4.load_code_cell('Wallet')
        # upgrade root
        call_set = CallSet('upgrade', input={'code': new_code.raw_})
        account.send_call_set(self.root, value=ts4.GRAM, call_set=call_set, expect_ec=1000)
        # upgrade wallet
        token_wallet = self._create_wallet()
        call_set = CallSet('upgrade', input={'remainingGasTo': account.address.str()})
        account.send_call_set(token_wallet, value=ts4.GRAM, call_set=call_set, expect_ec=1000)
        # upgrade wallet code
        call_set = CallSet('setWalletCode', input={'code': new_code.raw_})
        account.send_call_set(self.root, value=ts4.GRAM, call_set=call_set, expect_ec=1000)

    def _create_wallet(self) -> TokenWallet:
        token_wallet = self.deployer.create_token_wallet(self.root)
        self._sync_ts4_abi(token_wallet, 'TokenWalletUpgradeable')
        return token_wallet

    def _update_root(self, contract_name: str):
        new_code = ts4.load_code_cell(contract_name)
        call_set = CallSet('upgrade', input={'code': new_code.raw_})
        self.root.owner.send_call_set(self.root, value=ts4.GRAM, call_set=call_set)
        self._sync_ts4_abi(self.root, contract_name)

    def _set_wallet_code(self, contract_name: str):
        new_code = ts4.load_code_cell(contract_name)
        call_set = CallSet('setWalletCode', input={'code': new_code.raw_})
        self.root.owner.send_call_set(self.root, value=ts4.GRAM, call_set=call_set)

    def _update_wallet(self, token_wallet: TokenWallet, contract_name: str = None):
        call_set = CallSet('upgrade', input={'remainingGasTo': token_wallet.owner.address.str()})
        token_wallet.owner.send_call_set(token_wallet, value=ts4.GRAM, call_set=call_set)
        if contract_name:
            self._sync_ts4_abi(token_wallet, contract_name)

    @staticmethod
    def _sync_ts4_abi(contract: ts4.BaseContract, abi_file: str):
        contract.abi = Abi(abi_file)
        contract._init2(contract.name_, contract.address)
