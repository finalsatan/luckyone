// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Luckone} from "../../src/Luckone.sol";
import {DeployLuckone} from "../../script/DeployLuckone.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";

contract LuckoneTest is Test, CodeConstants {
    Luckone public luckone;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    LinkToken link;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

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

        link = LinkToken(config.link);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                LINK_BALANCE
            );
        }
        link.approve(vrfCoordinator, LINK_BALANCE);
        vm.stopPrank();
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

    /*//////////////////////////////////////////////////////////////
                              CHECKUPKEEP
    //////////////////////////////////////////////////////////////*/
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = luckone.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        luckone.enterLuckone{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        luckone.performUpkeep("");
        Luckone.LuckoneState luckoneState = luckone.getLuckoneState();
        // Act
        (bool upkeepNeeded, ) = luckone.checkUpkeep("");
        // Assert
        assert(luckoneState == Luckone.LuckoneState.CALCULATING);
        assert(upkeepNeeded == false);
    }

    // Challenge 1. testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        luckone.enterLuckone{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = luckone.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    // Challenge 2. testCheckUpkeepReturnsTrueWhenParametersGood
    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(PLAYER);
        luckone.enterLuckone{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = luckone.checkUpkeep("");
        // Assert
        assert(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORMUPKEEP
    //////////////////////////////////////////////////////////////*/
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        luckone.enterLuckone{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        // It doesnt revert
        luckone.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Luckone.LuckoneState lState = luckone.getLuckoneState();
        uint256 lastTimeStamp = luckone.getLastTimeStamp();
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Luckone.Luckone__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                lState,
                lastTimeStamp
            )
        );
        luckone.performUpkeep("");
    }

    function testPerformUpkeepUpdatesLuckoneStateAndEmitsRequestId() public {
        // Arrange
        vm.prank(PLAYER);
        luckone.enterLuckone{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        vm.recordLogs();
        luckone.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Luckone.LuckoneState luckoneState = luckone.getLuckoneState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint256(luckoneState) == 1); // 0 = open, 1 = calculating
    }

    /*//////////////////////////////////////////////////////////////
                           FULFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/
    modifier luckoneEntered() {
        vm.prank(PLAYER);
        luckone.enterLuckone{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep()
        public
        luckoneEntered
        skipFork
    {
        // Arrange
        // Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // vm.mockCall could be used here...
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            0,
            address(luckone)
        );

        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            1,
            address(luckone)
        );
    }

    // fuzz test
    function testFuzzFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public luckoneEntered skipFork {
        // Arrange
        // Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // vm.mockCall could be used here...
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(luckone)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        luckoneEntered
        skipFork
    {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            luckone.enterLuckone{value: entranceFee}();
        }

        uint256 startingTimeStamp = luckone.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        luckone.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(entries[1].topics[1]);
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(luckone)
        );

        // Assert
        address recentWinner = luckone.getRecentWinner();
        Luckone.LuckoneState luckoneState = luckone.getLuckoneState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = luckone.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(luckoneState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
