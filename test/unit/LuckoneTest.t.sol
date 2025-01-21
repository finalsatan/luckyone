// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Luckone} from "../../src/Luckone.sol";
import {DeployLuckone} from "../../script/DeployLuckone.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract LuckoneTest is Test, CodeConstants {
    Luckone public luckone;
    HelperConfig public helperConfig;

    uint256 public entranceFee;
    uint256 public interval;
    address public vrfCoordinator;
    address public link;
    address public account;
    bytes32 public gasLane;
    uint256 public subscriptionId;
    uint32 public callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() public {
        DeployLuckone deployLuckone = new DeployLuckone();
        (luckone, helperConfig) = deployLuckone.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.automationUpdateInterval;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinator = config.vrfCoordinatorV2_5;
        link = config.link;
        account = config.account;

        // 添加这些行来设置 VRF 消费者
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            address(luckone)
        );
        vm.stopBroadcast();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testLuckoneInitializesInOpenState() public view {
        assert(luckone.getLuckoneState() == Luckone.LuckoneState.OPEN);
    }

    function testLuckoneRevertsIfNotEnoughEth() public {
        // Arrange
        vm.prank(PLAYER);
        // Act/Assert
        vm.expectRevert(Luckone.Luckone__NotEnoughEthSent.selector);
        luckone.enterLuckone{value: 0.0001 ether}();
    }

    function testLuckoneRecordsPlayerEntrance() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        luckone.enterLuckone{value: entranceFee}();
        // Assert
        address playerEntered = luckone.getPlayer(0);
        assert(playerEntered == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);
        // Act/Assert
        vm.expectEmit(true, true, false, false, address(luckone));
        emit Luckone.EnterLuckone(PLAYER);
        luckone.enterLuckone{value: entranceFee}();
    }

    function testDontAllowEnteringWhileCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        luckone.enterLuckone{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        luckone.performUpkeep("");
        // Act/Assert
        vm.expectRevert(Luckone.Luckone__NotOpen.selector);
        vm.prank(PLAYER);
        luckone.enterLuckone{value: entranceFee}();
    }
}
