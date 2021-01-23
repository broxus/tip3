pragma solidity >= 0.6.0;

import './IEvent.sol';

interface IProxy {
    function broxusBridgeNotification(
        IEvent.EthereumEventInitData eventData
    ) external view;

    function broxusBridgeCallback(
        IEvent.EthereumEventInitData eventData,
        address gasBackAddress
    ) external;
}
