pragma ton-solidity >= 0.39.0;

library RootTokenContractErrors {
    uint8 constant error_message_sender_is_not_my_owner = 100;
    uint8 constant error_not_enough_balance = 101;
    uint8 constant error_message_sender_is_not_good_wallet = 102;
    uint8 constant error_define_public_key_or_owner_address = 103;
    uint8 constant error_paused = 104;
}
