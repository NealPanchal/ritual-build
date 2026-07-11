// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LLMPrecompileTest
/// @notice v0.3 — adds explicit lock duration handling after yesterday's
///         fee-funding fix. Lock duration is monotonic: it can only extend,
///         never shorten. This version makes that constraint visible in
///         the contract instead of leaving it as an implicit docs detail.
/// @dev Repo: github.com/NealPanchal/ritual-build

interface ILLMPrecompile {
    struct LLMRequest {
        string model;
        string prompt;
        uint256 maxTokens;
    }
    function infer(LLMRequest calldata request) external returns (string memory response);
}

interface IRitualWallet {
    function deposit(uint256 lockDuration) external payable;
    function balanceOf(address account) external view returns (uint256);
    function lockDurationOf(address account) external view returns (uint256); // confirm name against real ABI
}

contract LLMPrecompileTest {
    address constant LLM_PRECOMPILE = 0x0000000000000000000000000000000000000802;
    address constant RITUAL_WALLET  = 0x0000000000000000000000000000000000000100;

    // Explicit constants instead of a placeholder magic number —
    // pick these deliberately, this is the day-10 lesson.
    uint256 public constant DEV_LOCK_DURATION  = 1 days;
    uint256 public constant PROD_LOCK_DURATION = 30 days;

    string public lastResponse;
    address public owner;
    bool public walletFunded;
    uint256 public currentLockDuration;

    event WalletFunded(uint256 amount, uint256 lockDuration);
    event InferenceRequested(string prompt);
    event InferenceStored(string response);

    constructor() {
        owner = msg.sender;
    }

    /// @notice Fund with an explicit, named lock duration rather than an
    ///         arbitrary number. Reminder: lock duration only extends,
    ///         never shortens — pick deliberately, not as a placeholder.
    function fundWallet(uint256 lockDuration) external payable {
        require(msg.sender == owner, "not owner");
        require(
            lockDuration >= currentLockDuration,
            "cannot shorten existing lock duration"
        );

        IRitualWallet(RITUAL_WALLET).deposit{value: msg.value}(lockDuration);
        currentLockDuration = lockDuration;
        walletFunded = true;

        emit WalletFunded(msg.value, lockDuration);
    }

    function askModel(string calldata prompt, uint256 maxTokens) external {
        require(msg.sender == owner, "not owner");
        require(walletFunded, "fund RitualWallet before calling the precompile");

        ILLMPrecompile.LLMRequest memory req = ILLMPrecompile.LLMRequest({
            model: "default",
            prompt: prompt,
            maxTokens: maxTokens
        });

        emit InferenceRequested(prompt);
        string memory response = ILLMPrecompile(LLM_PRECOMPILE).infer(req);
        lastResponse = response;
        emit InferenceStored(response);
    }
}