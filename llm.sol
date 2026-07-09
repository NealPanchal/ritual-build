// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRitualWallet {
    function deposit(uint256 lockDuration) external payable;
    function balanceOf(address account) external view returns (uint256);
}

contract LLMPrecompileTest {
    address constant LLM_PRECOMPILE = 0x0000000000000000000000000000000000000802;
    // Corrected RITUAL_WALLET address
    address constant RITUAL_WALLET  = 0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948;

    string public lastResponse;
    address public owner;

    event InferenceRequested(string prompt);
    event InferenceCompleted(string model, bool hasError);

    constructor() {
        owner = msg.sender;
    }

    /// @notice Fund RitualWallet BEFORE calling askModel
    function fundWallet(uint256 lockDuration) external payable {
        IRitualWallet(RITUAL_WALLET).deposit{value: msg.value}(lockDuration);
    }

    /// @notice Request LLM inference
    function askModel(address executor, string calldata prompt, int256 maxTokens) external {
        require(msg.sender == owner, "not owner");

        string memory messagesJson = string(abi.encodePacked(
            '[{"role":"user","content":"', prompt, '"}]'
        ));

        // 30-field tuple for 0x0802 LLM Call
        bytes memory input = abi.encode(
            executor,
            new bytes[](0),   // encryptedSecrets
            uint256(300),     // ttl
            new bytes[](0),   // secretSignatures
            bytes(""),        // userPublicKey
            messagesJson,     // messagesJson
            "zai-org/GLM-4.7-FP8", // model
            int256(0),        // frequencyPenalty
            "",               // logitBiasJson
            false,            // logprobs
            maxTokens,        // maxCompletionTokens
            "",               // metadataJson
            "",               // modalitiesJson
            uint256(1),       // n
            true,             // parallelToolCalls
            int256(0),        // presencePenalty
            "medium",         // reasoningEffort
            bytes(""),        // responseFormatData
            int256(-1),       // seed (null)
            "auto",           // serviceTier
            "",               // stopJson
            bool(false),      // stream
            int256(700),      // temperature (0.7 × 1000)
            bytes(""),        // toolChoiceData
            bytes(""),        // toolsData
            int256(-1),       // topLogprobs (null)
            int256(1000),     // topP (1.0 × 1000)
            "",               // user
            bool(false),      // piiEnabled
            abi.encode("gcs", "", "") // convoHistory (dummy StorageRef)
        );

        emit InferenceRequested(prompt);

        (bool success, bytes memory result) = LLM_PRECOMPILE.call(input);
        require(success, "Precompile call failed");

        // The short-running async envelope is: (bytes simmedInput, bytes actualOutput)
        // If this is the initial simulation/commit, actualOutput is empty.
        // In the fulfilled replay, it contains the actual 5-field result.
        (, bytes memory actualOutput) = abi.decode(result, (bytes, bytes));

        if (actualOutput.length > 0) {
            (bool hasError, bytes memory completionData, , string memory errorMsg, ) =
                abi.decode(actualOutput, (bool, bytes, bytes, string, (string, string, string)));
            
            emit InferenceCompleted("zai-org/GLM-4.7-FP8", hasError);
            
            // Cannot easily parse `completionData` on-chain (it's ABI encoded),
            // but we can store errorMsg if there was an error.
            if (hasError) {
                lastResponse = errorMsg;
            } else {
                lastResponse = "Response stored in completionData / receipt";
            }
        } else {
            // initial call (commitment phase)
            lastResponse = "Deferred... Wait for transaction settlement.";
        }
    }
}