// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title CounterContract
/// @notice Day 20 — deliberately trivial goal for the recursive agent test.
///         The point isn't this contract; it's proving the coding agent
///         can generate, deploy, and fund something this simple end to end.
/// @dev Repo: github.com/NealPanchal/ritual-build
contract CounterContract {
    uint256 public count;
    address public owner;

    event Incremented(uint256 newCount);

    constructor() {
        owner = msg.sender;
    }

    function increment() external {
        count += 1;
        emit Incremented(count);
    }
}
