// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts@1.2.0/src/v0.8/automation/AutomationCompatible.sol";


/**
 * @title A sample raffle contract
 * @author Murphy233666
 * @notice This contract is for creating a sample raffle
 * @dev Implements chainlink VRFv2
 */
contract Luckone is VRFConsumerBaseV2Plus, AutomationCompatibleInterface  {
    /** Errors */
    error Luckone__NotEnoughEthSent();
    error Luckone__NotEnoughTimePassed();
    error Luckone__TransferFailed();
    error Luckone__NotOpen();
    error Luckone__UpkeepNotNeeded(uint256 balance, uint256 numPlayers, uint256 luckoneState, uint256 lastTimeStamp);
    
    /** Type Declarations */
    enum LuckoneState {
        OPEN,
        CALCULATING
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev duration of the lottery in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address payable private s_recentWinner;
    LuckoneState private s_luckoneState;
    /** Events  */
    event EnterLuckone(address indexed player);
    event PickWinner(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_luckoneState = LuckoneState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    function enterLuckone() external payable {
        if (msg.value < i_entranceFee) {
            revert Luckone__NotEnoughEthSent();
        }

        if (s_luckoneState != LuckoneState.OPEN) {
            revert Luckone__NotOpen();
        }

        s_players.push(payable(msg.sender));
        //1. make migration easier
        //2. make fontend "indexing" easier
        emit EnterLuckone(msg.sender);
    }

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
       bool timeHasPassed = (block.timestamp - s_lastTimeStamp) > i_interval;
       bool isOpen = s_luckoneState == LuckoneState.OPEN;
       bool hasPlayers = s_players.length > 0;
       bool hasBalance = address(this).balance > 0;
       upkeepNeeded = timeHasPassed && isOpen && hasPlayers && hasBalance;
       return (upkeepNeeded, "0x0");
    }

    // 1. get a random number
    // 2. use the random number to pick a winner
    // 3. be automatically called
    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Luckone__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_luckoneState),
                s_lastTimeStamp
            );
        }
        // check if enough time has passed
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert Luckone__NotEnoughTimePassed();
        }
        s_luckoneState = LuckoneState.CALCULATING;
        // 1. request the RNG
        // 2. get the random number
        s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                )
            })
        );
    }

    
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {
        // checks
        // effects
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;

        s_luckoneState = LuckoneState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        
        // interactions
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Luckone__TransferFailed();
        }
        emit PickWinner(winner);
    }

    /** Getter Function */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getLuckoneState() external view returns (LuckoneState) {
        return s_luckoneState;
    }
}
