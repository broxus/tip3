pragma solidity >= 0.6.0;

import './IEvent.sol';

interface IProxy {
    function broxusBridgeCallback(
        IEvent.EthereumEventInitData eventData
    ) external;
}
