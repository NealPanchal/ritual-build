// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title RecursiveAgentTrigger
/// @notice Day 20 — parent agent hands a goal to a coding agent via the
///         Autonomous Agents precompile. Coding agent reads
///         ritual-dapp-skills, generates + deploys a contract, funds its
///         own RitualWallet, and returns the live address to the parent.
/// @dev Repo: github.com/NealPanchal/ritual-build
///      CONFIRM real interface/addresses against ritual-dapp-agents before
///      relying on this — 0x0820/0x080C referenced in docs, exact ABI
///      not fully confirmed as of today.

interface IAutonomousAgentPrecompile {
    struct AgentGoal {
        string description;      // e.g. "deploy a counter contract"
        string skillsRepoRef;    // e.g. "ritual-dapp-skills"
        uint256 fundingAmount;   // amount to seed the child app's RitualWallet
    }

    /// @notice Spawns a coding agent to pursue the given goal.
    /// @return childAddress The live deployed address of the resulting app,
    ///         once the coding agent completes the build/deploy/fund flow.
    function delegateBuild(AgentGoal calldata goal)
        external
        payable
        returns (address childAddress);
}

interface IRitualWallet {
    function deposit(uint256 lockDuration) external payable;
}

contract RecursiveAgentTrigger {
    address constant AGENT_PRECOMPILE = 0x0000000000000000000000000000000000000820; // CONFIRM
    address constant RITUAL_WALLET    = 0x0000000000000000000000000000000000000100;

    address public owner;
    address public lastChildAddress;
    bool public walletFunded;

    event GoalDelegated(string description);
    event ChildAppDeployed(address indexed childAddress);

    constructor() {
        owner = msg.sender;
    }

    function fundWallet(uint256 lockDuration) external payable {
        require(msg.sender == owner, "not owner");
        IRitualWallet(RITUAL_WALLET).deposit{value: msg.value}(lockDuration);
        walletFunded = true;
    }

    /// @notice Triggers the recursive pattern with a deliberately trivial
    ///         goal — isolating whether the handoff itself works before
    ///         testing it against anything more complex.
    function triggerRecursiveBuild(uint256 childFunding) external payable {
        require(msg.sender == owner, "not owner");
        require(walletFunded, "fund RitualWallet before delegating");

        IAutonomousAgentPrecompile.AgentGoal memory goal = IAutonomousAgentPrecompile.AgentGoal({
            description: "deploy a counter contract",
            skillsRepoRef: "ritual-dapp-skills",
            fundingAmount: childFunding
        });

        emit GoalDelegated(goal.description);

        address childAddress = IAutonomousAgentPrecompile(AGENT_PRECOMPILE)
            .delegateBuild{value: childFunding}(goal);

        lastChildAddress = childAddress;
        emit ChildAppDeployed(childAddress);
    }
}
