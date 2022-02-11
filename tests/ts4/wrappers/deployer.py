from tonos_ts4 import ts4

from config import BUILD_ARTIFACTS_PATH, VERBOSE, NAME, SYMBOL, DECIMALS, DEPLOY_WALLET_VALUE
from utils import random_address, ZERO_ADDRESS
from wrappers.account import Account
from wrappers.token_root import TokenRoot
from wrappers.token_wallet import TokenWallet


class Deployer:

    def __init__(self):
        ts4.init(BUILD_ARTIFACTS_PATH, verbose=VERBOSE)
        self.token_factory = self.create_token_factory()

    @staticmethod
    def create_token_factory() -> ts4.BaseContract:
        return ts4.BaseContract('TestTokenFactory', {
            'owner': random_address(),
            'deployValue': 2 * ts4.GRAM,
            'rootCode': ts4.load_code_cell('TokenRoot'),
            'walletCode': ts4.load_code_cell('TokenWallet'),
            'rootUpgradeableCode': ts4.load_code_cell('TokenRootUpgradeable'),
            'walletUpgradeableCode': ts4.load_code_cell('TokenWalletUpgradeable'),
            'platformCode': ts4.load_code_cell('TokenWalletPlatform'),
        }, nickname='Factory', override_address=random_address())

    @staticmethod
    def create_account(contract_name: str = None, **kwargs) -> Account:
        if contract_name is None:
            return Account()
        else:
            return Account(contract_name, kwargs)

    def create_token_root(
            self,
            owner: Account,
            name: str = NAME,
            symbol: str = SYMBOL,
            decimals: int = DECIMALS,
            initial_supply_to: ts4.Address = ZERO_ADDRESS,
            initial_supply: int = 0,
            mint_disabled: bool = True,
            burn_by_root_disabled: bool = True,
            burn_paused: bool = False,
            remaining_gas_to: ts4.Address = ZERO_ADDRESS,
            upgradeable: bool = False,
    ) -> TokenRoot:
        root_address = self.token_factory.call_method('deployRootTest', {
            'name': name,
            'symbol': symbol,
            'decimals': decimals,
            'owner': owner.address,
            'initialSupplyTo': initial_supply_to,
            'initialSupply': initial_supply,
            'deployWalletValue': DEPLOY_WALLET_VALUE,
            'mintDisabled': mint_disabled,
            'burnByRootDisabled': burn_by_root_disabled,
            'burnPaused': burn_paused,
            'remainingGasTo': remaining_gas_to,
            'upgradeable': upgradeable,
            'answerId': 0,
        })
        ts4.dispatch_messages()
        return TokenRoot(root_address, owner)

    def create_token_wallet(self, root: TokenRoot) -> TokenWallet:
        account = self.create_account(contract_name='TestWalletCallback', root=root.address)
        account.call_method('deployWallet', {
            'walletOwner': account.address,
            'deployWalletValue': DEPLOY_WALLET_VALUE,
        })
        ts4.dispatch_messages()
        return root.wallet_of(account)
