pragma ton-solidity >= 0.39.0;

library TONTokenWalletErrors {
    uint8 constant error_message_sender_is_not_my_owner            = 100;
    uint8 constant error_not_enough_balance                        = 101;
    uint8 constant error_message_sender_is_not_my_root             = 102;
    uint8 constant error_message_sender_is_not_good_wallet         = 103;
    uint8 constant error_wrong_bounced_header                      = 104;
    uint8 constant error_wrong_bounced_args                        = 105;
    uint8 constant error_non_zero_remaining                        = 106;
    uint8 constant error_no_allowance_set                          = 107;
    uint8 constant error_wrong_spender                             = 108;
    uint8 constant error_not_enough_allowance                      = 109;
    uint8 constant error_low_message_value                         = 110;
    uint8 constant error_wrong_recipient                           = 111;
    uint8 constant error_recipient_has_disallow_non_notifiable     = 112;
}
