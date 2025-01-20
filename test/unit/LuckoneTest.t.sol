// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Luckone} from "../../src/Luckone.sol";
import {DeployLuckone} from "../../script/DeployLuckone.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract LuckoneTest is Test {
    Luckone public luckone;
    address public player;
    HelperConfig public helperConfig;
    uint256 public entranceFee;
    uint256 public interval;
    address public vrfCoordinator;
    bytes32 public gasLane;
    uint64 public subscriptionId;
    uint32 public callbackGasLimit;
    uint256 public constant STARTING_BALANCE = 10 ether;

    function setUp() public {
        DeployLuckone deployLuckone = new DeployLuckone();
        (luckone, helperConfig) = deployLuckone.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        ) = helperConfig.activeNetworkConfig();

        // 添加这些行来设置 VRF 消费者
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, address(luckone));
        vm.stopBroadcast();
        
        player = makeAddr("player");
        vm.deal(player, STARTING_BALANCE);
    }

    function testLuckoneInitializesInOpenState() public view {
        assert(luckone.getLuckoneState() == Luckone.LuckoneState.OPEN);
    }

    function testLuckoneRevertsIfNotEnoughEth() public {
        // Arrange
        vm.prank(player);
        // Act/Assert
        vm.expectRevert(Luckone.Luckone__NotEnoughEthSent.selector);
        luckone.enterLuckone{value: 0.0001 ether}();
    }

    function testLuckoneRecordsPlayerEntrance() public {
        // Arrange
        vm.prank(player);
        // Act
        luckone.enterLuckone{value: entranceFee}();
        // Assert
        address playerEntered = luckone.getPlayer(0);
        assert(playerEntered == player);
    }

    function testEmitsEventOnEntrance() public {
        // Arrange
        vm.prank(player);
        // Act/Assert
        vm.expectEmit(true, true, false, false, address(luckone));
        emit Luckone.EnterLuckone(player);
        luckone.enterLuckone{value: entranceFee}();
    }

    function testDontAllowEnteringWhileCalculating() public {
        // Arrange
        vm.prank(player);
        luckone.enterLuckone{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        luckone.performUpkeep("");
        // Act/Assert
        vm.expectRevert(Luckone.Luckone__NotOpen.selector);
        vm.prank(player);
        luckone.enterLuckone{value: entranceFee}();
    }
}
