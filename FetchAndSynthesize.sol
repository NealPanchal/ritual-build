// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title FetchAndSynthesize
/// @notice Day 12 — first chained HTTP → LLM attempt. Composes the two
///         precompiles verified in isolation on days 6-11. First attempt
///         deliberately does NO parsing between the fetch and the
///         inference step, to see what breaks before fixing it.
/// @dev Repo: github.com/NealPanchal/ritual-build
///      Kept separate from HTTPPrecompileTest.sol / LLMPrecompileTest.sol
///      so each precompile's isolated behavior stays provable on its own.

interface IHTTPPrecompile {
    struct HTTPRequest {
        string url;
        string method;
        string headers;
        string body;
    }
    function fetch(HTTPRequest calldata request) external returns (string memory response);
}

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
}

contract FetchAndSynthesize {
    address constant HTTP_PRECOMPILE = 0x0000000000000000000000000000000000000801;
    address constant LLM_PRECOMPILE  = 0x0000000000000000000000000000000000000802;
    address constant RITUAL_WALLET   = 0x0000000000000000000000000000000000000100;

    string public lastRawFetch;    // unparsed HTTP response — kept for debugging
    string public lastSynthesis;   // LLM output on that raw response
    address public owner;
    bool public walletFunded;

    event WalletFunded(uint256 amount, uint256 lockDuration);
    event FetchStored(string raw);
    event SynthesisStored(string result);

    constructor() {
        owner = msg.sender;
    }

    function fundWallet(uint256 lockDuration) external payable {
        require(msg.sender == owner, "not owner");
        IRitualWallet(RITUAL_WALLET).deposit{value: msg.value}(lockDuration);
        walletFunded = true;
        emit WalletFunded(msg.value, lockDuration);
    }

    /// @notice FIRST ATTEMPT — raw HTTP response passed directly as the
    ///         LLM prompt, no parsing in between. Known issue: unparsed
    ///         JSON confuses the model. Left as-is on purpose to document
    ///         the failure mode before the day 13 cleanup fix.
    function fetchAndSynthesizeRaw(string calldata url) external {
        require(msg.sender == owner, "not owner");
        require(walletFunded, "fund RitualWallet before calling a precompile");

        // Step 1: fetch
        IHTTPPrecompile.HTTPRequest memory httpReq = IHTTPPrecompile.HTTPRequest({
            url: url,
            method: "GET",
            headers: "",
            body: ""
        });
        string memory raw = IHTTPPrecompile(HTTP_PRECOMPILE).fetch(httpReq);
        lastRawFetch = raw;
        emit FetchStored(raw);

        // Step 2: synthesize — NO PARSING YET, this is the known bug
        ILLMPrecompile.LLMRequest memory llmReq = ILLMPrecompile.LLMRequest({
            model: "default",
            prompt: raw, // <-- raw JSON straight into the prompt, confuses the model
            maxTokens: 256
        });
        string memory result = ILLMPrecompile(LLM_PRECOMPILE).infer(llmReq);
        lastSynthesis = result;
        emit SynthesisStored(result);
    }

    // TODO (day 13): add a parsing/cleanup step here before the prompt is built.
}
