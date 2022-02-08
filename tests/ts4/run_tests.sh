#python3 -m unittest test_root_deploy.TestRootDeploy
#python3 -m unittest test_root_methods.TestRootMethods
#python3 -m unittest test_wallet_methods.TestWalletMethods
#python3 -m unittest test_wallet_transfer.TestWalletTransfer
#python3 -m unittest test_mint.TestMint
#python3 -m unittest test_burn.TestBurn
#python3 -m unittest test_burn.TestUpgradeable
python3 -m unittest discover -s . -p 'test_*.py'
