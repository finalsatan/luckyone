// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Luckone} from "../../src/Luckone.sol";
import {DeployLuckone} from "../../script/DeployLuckone.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

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
        player = makeAddr("player");
        vm.deal(player, STARTING_BALANCE);
    }

    function testLuckoneInitializesInOpenState() public view {
        assert(luckone.getLuckoneState() == Luckone.LuckoneState.OPEN);
    }
}
