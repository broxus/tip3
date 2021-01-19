pragma solidity >= 0.6.0;
pragma AbiHeader expire;


import "./../interfaces/IProxy.sol";
import "./../interfaces/IEvent.sol";
import "../utils/ErrorCodes.sol";


contract EthereumEvent is IEvent, ErrorCodes {
    EthereumEventInitData static initData;

    Status status;

    uint[] confirmKeys;
    uint[] rejectKeys;


    modifier eventInProcess() {
        require(status == Status.InProcess, EVENT_NOT_IN_PROGRESS);
        _;
    }

    modifier onlyEventConfiguration(address configuration) {
        require(msg.sender == configuration, SENDER_NOT_EVENT_CONFIGURATION);
        _;
    }

    /*
        Ethereum-TON event instance. Collects confirmations and than execute the Proxy callback.
        @dev Should be deployed only by EthereumEventConfiguration contract
        @param relayKey Public key of the relay, who initiated the event creation
    */
    constructor(
        uint relayKey
    ) public {
        // TODO: discuss deployer set in the constructor
        tvm.accept();

        initData.ethereumEventConfiguration = msg.sender;
        status = Status.InProcess;

        confirm(relayKey);
    }

    /*
        Confirm event instance.
        @dev Should be called by Bridge -> EthereumEventConfiguration
        @param relayKey Public key of the relay, who initiated the config creation
    */
    function confirm(
        uint relayKey
    )
        public
        onlyEventConfiguration(initData.ethereumEventConfiguration)
        eventInProcess
    {
        for (uint i=0; i<confirmKeys.length; i++) {
            require(confirmKeys[i] != relayKey, KEY_ALREADY_CONFIRMED);
        }

        confirmKeys.push(relayKey);

        if (confirmKeys.length >= initData.requiredConfirmations) {
            _executeProxyCallback();
            status = Status.Confirmed;

            initData.ethereumEventConfiguration.transfer({ value: address(this).balance - 1.5 ton });
        }
    }

    /*
        Reject event instance.
        @dev Should be called by Bridge -> EthereumEventConfiguration
        @param relayKey Public key of the relay, who initiated the config creation
    */
    function reject(
        uint relayKey
    )
        public
        onlyEventConfiguration(initData.ethereumEventConfiguration)
        eventInProcess
    {
        for (uint i=0; i<rejectKeys.length; i++) {
            require(rejectKeys[i] != relayKey, KEY_ALREADY_REJECTED);
        }

        rejectKeys.push(relayKey);

        if (rejectKeys.length >= initData.requiredRejects) {
            status = Status.Rejected;

            initData.ethereumEventConfiguration.transfer({ value: address(this).balance - 1.5 ton });
        }
    }

    /*
        Execute callback on proxy contract
        @dev Called internally, after required amount of confirmations received
    */
    function _executeProxyCallback() internal view {
        IProxy(initData.proxyAddress).broxusBridgeCallback{value: 1 ton}(initData);
    }

    /*
        Read contract details
        @returns _initData Init data
        @returns _status Current event status
        @returns _confirmKeys List of confirm keys
        @returns _rejectKeys List of reject keys
    */
    function getDetails() public view returns (
        EthereumEventInitData _initData,
        Status _status,
        uint[] _confirmKeys,
        uint[] _rejectKeys
    ) {
        return (
            initData,
            status,
            confirmKeys,
            rejectKeys
        );
    }
}
