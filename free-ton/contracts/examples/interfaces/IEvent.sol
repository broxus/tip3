pragma solidity >= 0.6.0;

interface IEvent {
    struct TonEventInitData {
        uint eventTransaction;
        uint64 eventTransactionLt;
        uint32 eventTimestamp;
        uint32 eventIndex;
        TvmCell eventData;
        address tonEventConfiguration;
        uint16 requiredConfirmations;
        uint16 requiredRejects;
        TvmCell configurationMeta;
    }

    // for confirming/rejecting TON event
    struct TonEventVoteData {
        uint eventTransaction;
        uint64 eventTransactionLt;
        uint32 eventTimestamp;
        uint32 eventIndex;
        TvmCell eventData;
    }

    struct EthereumEventInitData {
        uint eventTransaction;
        uint32 eventIndex;
        TvmCell eventData;
        uint32 eventBlockNumber;
        uint eventBlock;
        address ethereumEventConfiguration;
        uint16 requiredConfirmations;
        uint16 requiredRejects;
        address proxyAddress;
        TvmCell configurationMeta;
    }

    // for confirming/rejecting ETH event
    struct EthereumEventVoteData {
        uint eventTransaction;
        uint32 eventIndex;
        TvmCell eventData;
        uint32 eventBlockNumber;
        uint eventBlock;
    }

    enum EthereumEventStatus { InProcess, Confirmed, Executed, Rejected }
    enum TonEventStatus { InProcess, Confirmed, Rejected }
}

