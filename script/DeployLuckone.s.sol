// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Luckone} from "../src/Luckone.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "./Interactions.s.sol";

contract DeployLuckone is Script {
    function run() external returns (Luckone, HelperConfig) {
        // 获取配置参数
        HelperConfig helperConfig = new HelperConfig();
        AddConsumer addConsumer = new AddConsumer();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (
                config.subscriptionId,
                config.vrfCoordinatorV2_5
            ) = createSubscription.run();

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinatorV2_5,
                config.subscriptionId,
                config.link,
                config.account
            );

            helperConfig.setConfig(block.chainid, config);
        }

        vm.startBroadcast(config.account);
        Luckone luckone = new Luckone(
            config.entranceFee,
            config.automationUpdateInterval,
            config.vrfCoordinatorV2_5,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        addConsumer.addConsumer(
            address(luckone),
            config.vrfCoordinatorV2_5,
            config.subscriptionId,
            config.account
        );
        return (luckone, helperConfig);
    }
}
