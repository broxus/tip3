pragma ton-solidity >= 0.56.0;

interface ICallbackParamsStructure {
    struct CallbackParams {
        uint128 value;
        uint8 flag;
        TvmCell payload;
    }
}
