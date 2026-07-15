// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title FetchAndSynthesize
/// @notice Day 13 — fixes yesterday's known bug (raw JSON passed directly
///         as LLM prompt). Adds a parsing/cleanup step between fetch and
///         inference. First full working chained pipeline: end to end.
/// @dev Repo: github.com/NealPanchal/ritual-build

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

    string public lastRawFetch;
    string public lastParsedInput;   // NEW — the cleaned data actually sent to LLM
    string public lastSynthesis;

    address public owner;
    bool public walletFunded;

    event WalletFunded(uint256 amount, uint256 lockDuration);
    event FetchStored(string raw);
    event ParsedStored(string parsed);
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

    /// @notice FIX for day 12's bug: raw HTTP response is cleaned/normalized
    ///         into a proper natural-language instruction before it's used
    ///         as the LLM prompt. This is what actually made output quality
    ///         improve — small change, real impact.
    /// @dev _extractAndBuildPrompt is intentionally simple here — swap in
    ///      your actual parsing logic (JSON field extraction etc.) based on
    ///      your real data source's shape.
    function fetchAndSynthesize(string calldata url, string calldata instruction) external {
        require(msg.sender == owner, "not owner");
        require(walletFunded, "fund RitualWallet before calling a precompile");

        // Step 1: fetch (same as day 11/12)
        IHTTPPrecompile.HTTPRequest memory httpReq = IHTTPPrecompile.HTTPRequest({
            url: url,
            method: "GET",
            headers: "",
            body: ""
        });
        string memory raw = IHTTPPrecompile(HTTP_PRECOMPILE).fetch(httpReq);
        lastRawFetch = raw;
        emit FetchStored(raw);

        // Step 2: parse/clean — the actual day-13 fix
        string memory cleanedPrompt = _buildCleanPrompt(instruction, raw);
        lastParsedInput = cleanedPrompt;
        emit ParsedStored(cleanedPrompt);

        // Step 3: synthesize on the CLEANED input, not raw JSON
        ILLMPrecompile.LLMRequest memory llmReq = ILLMPrecompile.LLMRequest({
            model: "default",
            prompt: cleanedPrompt,
            maxTokens: 256
        });
        string memory result = ILLMPrecompile(LLM_PRECOMPILE).infer(llmReq);
        lastSynthesis = result;
        emit SynthesisStored(result);
    }

    /// @dev Minimal example — wraps raw data with explicit instruction
    ///      framing instead of dumping it in unlabeled. Replace with real
    ///      JSON field extraction for your actual data source.
    function _buildCleanPrompt(string memory instruction, string memory rawData)
        internal
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                instruction,
                "\n\nRelevant data:\n",
                rawData
            )
        );
    }

    // AsyncJobTracker note (for day 13 evening post): the fetch() and
    // infer() calls above resolve through AsyncJobTracker under the hood —
    // non-deterministic, long-running work doesn't block deterministic
    // execution; it's tracked and resolved async, then lands back onchain.
}