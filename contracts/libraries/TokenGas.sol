pragma ton-solidity >= 0.39.0;

library TokenGas {
    uint128 constant TOKEN_ROOT_DEPLOY_MIN_VALUE                    = 2 ton;
    uint128 constant TARGET_ROOT_BALANCE                            = 1 ton;
    uint128 constant TARGET_WALLET_BALANCE                          = 0.1 ton;

    uint128 constant MINT_MIN_VALUE                                 = 0.3 ton;

    uint128 constant WALLET_UPGRADE_MIN_VALUE                       = 1 ton;
    uint128 constant WALLET_DEPLOY_MIN_VALUE                        = 0.1 ton;
    uint128 constant WALLET_DEPLOY_WITH_CALLBACK_ADDITIONAL_VALUE   = 0.2 ton;
}
