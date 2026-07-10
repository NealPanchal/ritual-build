// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LLMPrecompileTest
/// @notice Fixed version — funds RitualWallet BEFORE any precompile call.
/// @dev Verify precompile address + ABI against ritual-dapp-precompiles.
///      Repo: github.com/NealPanchal/ritual-build

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
}

contract LLMPrecompileTest {
    address constant LLM_PRECOMPILE = 0x0000000000000000000000000000000000000802;
    address constant RITUAL_WALLET  = 0x0000000000000000000000000000000000000100;

    string public lastResponse;
    address public owner;
    bool public walletFunded;

    event WalletFunded(uint256 amount, uint256 lockDuration);
    event InferenceRequested(string prompt);
    event InferenceStored(string response);

    constructor() {
        owner = msg.sender;
    }

    /// @notice THE FIX: this must be called before askModel(), not after.
    ///         Precompile calls are paid from a prepaid balance, not
    ///         pulled ad hoc at call time. Yesterday's revert was here.
    function fundWallet(uint256 lockDuration) external payable {
        require(msg.sender == owner, "not owner");
        IRitualWallet(RITUAL_WALLET).deposit{value: msg.value}(lockDuration);
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