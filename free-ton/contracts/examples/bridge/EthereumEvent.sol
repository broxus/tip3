pragma solidity >= 0.6.0;
pragma AbiHeader expire;


import "./../interfaces/IProxy.sol";
import "./../interfaces/IEvent.sol";
import "../utils/ErrorCodes.sol";


contract EthereumEvent is IEvent, ErrorCodes {
    EthereumEventInitData static initData;

    enum Status { InProcess, Confirmed, Executed, Rejected }
    Status status;

    address[] confirmRelays;
    address[] rejectRelays;


    modifier eventInProcess() {
        require(status == Status.InProcess, EVENT_NOT_IN_PROGRESS);
        _;
    }

    modifier eventConfirmed() {
        require(status == Status.Confirmed, EVENT_NOT_CONFIRMED);
        _;
    }

    modifier onlyEventConfiguration(address configuration) {
        require(msg.sender == configuration, SENDER_NOT_EVENT_CONFIGURATION);
        _;
    }

    /*
        Ethereum-TON event instance. Collects confirmations and than execute the Proxy callback.
        @dev Should be deployed only by EthereumEventConfiguration contract
        @param relay Public key of the relay, who initiated the event creation
    */
    constructor(
        address relay
    ) public {
        // TODO: discuss deployer set in the constructor
        tvm.accept();

        initData.ethereumEventConfiguration = msg.sender;
        status = Status.InProcess;

        confirm(relay);
    }

    /*
        Confirm event instance.
        @dev Should be called by Bridge -> EthereumEventConfiguration
        @param relay Address of the relay, who initiated the config creation
    */
    function confirm(
        address relay
    )
        public
        onlyEventConfiguration(initData.ethereumEventConfiguration)
        eventInProcess
    {
        for (uint i=0; i<confirmRelays.length; i++) {
            require(confirmRelays[i] != relay, KEY_ALREADY_CONFIRMED);
        }

        confirmRelays.push(relay);

        if (confirmRelays.length >= initData.requiredConfirmations) {
            executeProxyNotification();

            status = Status.Confirmed;

            initData.ethereumEventConfiguration.transfer({ value: address(this).balance - 1.5 ton });
        }
    }

    /*
        Reject event instance.
        @dev Should be called by Bridge -> EthereumEventConfiguration
        @param relay Public key of the relay, who initiated the config creation
    */
    function reject(
        address relay
    )
        public
        onlyEventConfiguration(initData.ethereumEventConfiguration)
        eventInProcess
    {
        for (uint i=0; i<rejectRelays.length; i++) {
            require(rejectRelays[i] != relay, KEY_ALREADY_REJECTED);
        }

        rejectRelays.push(relay);

        if (rejectRelays.length >= initData.requiredRejects) {
            status = Status.Rejected;

            initData.ethereumEventConfiguration.transfer({ value: address(this).balance - 0.1 ton });
        }
    }

    function executeProxyNotification() internal view {
        IProxy(initData.proxyAddress).broxusBridgeNotification{value: 0.00001 ton}(initData);
    }

    /*
        Execute callback on proxy contract
        @dev Called internally, after required amount of confirmations received
    */
    function executeProxyCallback() public eventConfirmed {
        status = Status.Executed;

        uint128 balance = address(this).balance;

        IProxy(initData.proxyAddress).broxusBridgeCallback{value: msg.value - 0.1 ton}(initData);

//        initData.ethereumEventConfiguration.transfer({ value: balance - 0.1 ton });
    }

    /*
        Read contract details
        @returns _initData Init data
        @returns _status Current event status
        @returns _confirmRelays List of confirm keys
        @returns _rejectRelays List of reject keys
    */
    function getDetails() public view returns (
        EthereumEventInitData _initData,
        Status _status,
        address[] _confirmRelays,
        address[] _rejectRelays
    ) {
        return (
            initData,
            status,
            confirmRelays,
            rejectRelays
        );
    }
}
