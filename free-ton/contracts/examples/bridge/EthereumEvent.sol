pragma solidity >= 0.6.0;
pragma AbiHeader expire;


import "./../interfaces/IProxy.sol";
import "./../interfaces/IEvent.sol";
import "./../interfaces/IEventNotificationReceiver.sol";

import "./../utils/ErrorCodes.sol";
import "./../utils/TransferUtils.sol";

import "./../additional/CellEncoder.sol";


contract EthereumEvent is IEvent, ErrorCodes, TransferUtils, CellEncoder {
    EthereumEventInitData static initData;

    EthereumEventStatus status;

    address[] confirmRelays;
    address[] rejectRelays;


    modifier eventInProcess() {
        require(status == EthereumEventStatus.InProcess, EVENT_NOT_IN_PROGRESS);
        _;
    }

    modifier eventConfirmed() {
        require(status == EthereumEventStatus.Confirmed, EVENT_NOT_CONFIRMED);
        _;
    }

    modifier onlyEventConfiguration(address configuration) {
        require(msg.sender == configuration, SENDER_NOT_EVENT_CONFIGURATION);
        _;
    }

    /*
        Notify specific contract that event contract status has been changed
        @dev In this example, notification receiver is derived from the configuration meta
    */
    function notifyEventStatusChanged() internal view {
        (,,,,,address owner_address) = getDecodedData();

        // TODO: discuss minimum value of the notification
        if (owner_address.value != 0) {
            IEventNotificationReceiver(owner_address).notifyEthereumEventStatusChanged{value: 0.00001 ton}(status);
        }
    }

    /*
        Ethereum-TON event instance. Collects confirmations and than execute the Proxy callback.
        @dev Should be deployed only by EthereumEventConfiguration contract
        @param relay Public key of the relay, who initiated the event creation
    */
    constructor(
        address relay
    ) public {
        initData.ethereumEventConfiguration = msg.sender;
        status = EthereumEventStatus.InProcess;

        notifyEventStatusChanged();

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
            status = EthereumEventStatus.Confirmed;

            notifyEventStatusChanged();
//            TODO: fix problem with freezing contract after emptying balance
            transferAll(initData.ethereumEventConfiguration);
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
            status = EthereumEventStatus.Rejected;

            notifyEventStatusChanged();
            transferAll(initData.ethereumEventConfiguration);
        }
    }

    /*
        Execute callback on proxy contract
        @dev Anyone can call this in case event is in Confirmed status
        @dev May be called only once, because status will be changed to Executed
    */
    function executeProxyCallback() public eventConfirmed {
        require(msg.value > 1 ton, TOO_LOW_MSG_VALUE);
        status = EthereumEventStatus.Executed;

        notifyEventStatusChanged();
        IProxy(initData.proxyAddress).broxusBridgeCallback{value: 0, flag: 64}(initData, msg.sender);
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
        EthereumEventStatus _status,
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

    function getDecodedData() public view returns (
        address rootToken,
        uint128 tokens,
        int8 wid,
        uint256 owner_addr,
        uint256 owner_pubkey,
        address owner_address
    ) {
        (rootToken) = decodeConfigurationMeta(initData.configurationMeta);

        (
            tokens,
            wid,
            owner_addr,
            owner_pubkey
        ) = decodeEthereumEventData(initData.eventData);

        owner_address = address.makeAddrStd(wid, owner_addr);
    }
}
