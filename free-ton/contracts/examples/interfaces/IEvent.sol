pragma solidity >= 0.6.0;

interface IEvent {
    struct TonEventInitData {
        uint eventTransaction;
        uint eventIndex;
        TvmCell eventData;
        uint eventBlockNumber;
        uint eventBlock;
        address tonEventConfiguration;
        uint requiredConfirmations;
        uint requiredRejects;
    }

    struct EthereumEventInitData {
        uint eventTransaction;
        uint eventIndex;
        TvmCell eventData;
        uint eventBlockNumber;
        uint eventBlock;
        address ethereumEventConfiguration;
        uint requiredConfirmations;
        uint requiredRejects;
        address proxyAddress;
    }

    enum Status { InProcess, Confirmed, Rejected }
}
