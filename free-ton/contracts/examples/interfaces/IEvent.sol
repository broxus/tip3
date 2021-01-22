pragma solidity >= 0.6.0;

interface IEvent {
    struct TonEventInitData {
        uint eventTransaction;
        uint64 eventTransactionLt;
        uint32 eventIndex;
        TvmCell eventData;
        address tonEventConfiguration;
        uint requiredConfirmations;
        uint requiredRejects;
    }

    // for confirming/rejecting TON event
    struct TonEventVoteData {
        uint eventTransaction;
        uint64 eventTransactionLt;
        uint32 eventIndex;
        TvmCell eventData;
    }

    struct EthereumEventInitData {
        uint eventTransaction;
        uint32 eventIndex;
        TvmCell eventData;
        uint eventBlockNumber;
        uint eventBlock;
        address ethereumEventConfiguration;
        uint requiredConfirmations;
        uint requiredRejects;
        address proxyAddress;
    }

    // for confirming/rejecting ETH event
    struct EthereumEventVoteData {
        uint eventTransaction;
        uint32 eventIndex;
        TvmCell eventData;
        uint eventBlockNumber;
        uint eventBlock;
    }
}
