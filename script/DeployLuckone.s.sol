// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Luckone} from "../src/Luckone.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployLuckone is Script {
    function run() external returns (Luckone, HelperConfig) {
        // 获取配置参数
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            bytes32 gasLane,
            uint256 subscriptionId,
            uint32 callbackGasLimit,
            address vrfCoordinator,
            address link,
            address account
        ) = helperConfig.activeNetworkConfig();

        // 开始广播交易
        vm.startBroadcast();

        // 部署 Luckone 合约
        Luckone luckone = new Luckone(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );

        vm.stopBroadcast();

        return (luckone, helperConfig);
    }
}
