// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title FetchAndSynthesize
/// @notice Day 17 — wires the Scheduler precompile to trigger the
///         fetch → parse → synthesize → write pipeline once daily,
///         removing the need for manual triggering.
///         Day 18 — added explicit max token budget per scheduled call.
/// @dev Repo: github.com/NealPanchal/ritual-build
///      Confirm ISchedulerPrecompile signature against ritual-dapp-scheduler
///      before relying on this in production — interface below reflects
///      what's confirmed as of today's docs read.

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

interface ISchedulerPrecompile {
    function registerRecurring(
        address target,
        bytes4 selector,
        uint256 interval
    ) external returns (uint256 jobId);

    function cancel(uint256 jobId) external;
}

contract FetchAndSynthesize {
    address constant HTTP_PRECOMPILE      = 0x0000000000000000000000000000000000000801;
    address constant LLM_PRECOMPILE       = 0x0000000000000000000000000000000000000802;
    address constant RITUAL_WALLET        = 0x0000000000000000000000000000000000000100;
    address constant SCHEDULER_PRECOMPILE = 0x0000000000000000000000000000000000000110; // CONFIRM real address

    string public dataSourceUrl;
    string public instruction;

    string public lastRawFetch;
    string public lastParsedInput;
    string public lastSynthesis;

    address public owner;
    bool public walletFunded;
    uint256 public schedulerJobId;
    bool public scheduled;

    /// @notice Day 18 — added an explicit max token budget per scheduled
    ///         call, replacing the fixed 256 used since day 13. Prevents
    ///         cost drift on a job that runs itself unattended.
    uint256 public maxTokensPerRun = 200;

    event WalletFunded(uint256 amount, uint256 lockDuration);
    event FetchStored(string raw);
    event ParsedStored(string parsed);
    event SynthesisStored(string result);
    event ScheduleRegistered(uint256 jobId, uint256 interval);
    event MaxTokensUpdated(uint256 oldValue, uint256 newValue);

    constructor(string memory _url, string memory _instruction) {
        owner = msg.sender;
        dataSourceUrl = _url;
        instruction = _instruction;
    }

    function setMaxTokens(uint256 newMax) external {
        require(msg.sender == owner, "not owner");
        require(newMax > 0, "must be positive");
        emit MaxTokensUpdated(maxTokensPerRun, newMax);
        maxTokensPerRun = newMax;
    }

    function fundWallet(uint256 lockDuration) external payable {
        require(msg.sender == owner, "not owner");
        IRitualWallet(RITUAL_WALLET).deposit{value: msg.value}(lockDuration);
        walletFunded = true;
        emit WalletFunded(msg.value, lockDuration);
    }

    /// @notice NEW — registers this contract's own runPipeline() selector
    ///         with the Scheduler precompile, once daily (86400s).
    ///         Deliberately NOT calling runPipeline() manually after this —
    ///         want to confirm it fires on its own before trusting it.
    function scheduleDaily() external {
        require(msg.sender == owner, "not owner");
        require(walletFunded, "fund RitualWallet before scheduling");
        require(!scheduled, "already scheduled");

        uint256 jobId = ISchedulerPrecompile(SCHEDULER_PRECOMPILE).registerRecurring(
            address(this),
            this.runPipeline.selector,
            1 days
        );

        schedulerJobId = jobId;
        scheduled = true;
        emit ScheduleRegistered(jobId, 1 days);
    }

    /// @notice The actual pipeline logic, now callable by the Scheduler
    ///         precompile itself, not just manually by the owner.
    function runPipeline() external {
        require(
            msg.sender == owner || msg.sender == SCHEDULER_PRECOMPILE,
            "unauthorized caller"
        );
        require(walletFunded, "fund RitualWallet before running");

        IHTTPPrecompile.HTTPRequest memory httpReq = IHTTPPrecompile.HTTPRequest({
            url: dataSourceUrl,
            method: "GET",
            headers: "",
            body: ""
        });
        string memory raw = IHTTPPrecompile(HTTP_PRECOMPILE).fetch(httpReq);
        lastRawFetch = raw;
        emit FetchStored(raw);

        string memory cleanedPrompt = _buildCleanPrompt(instruction, raw);
        lastParsedInput = cleanedPrompt;
        emit ParsedStored(cleanedPrompt);

        // changed from a fixed 256:
        ILLMPrecompile.LLMRequest memory llmReq = ILLMPrecompile.LLMRequest({
            model: "default",
            prompt: cleanedPrompt,
            maxTokens: maxTokensPerRun   // now configurable, was: 256
        });
        string memory result = ILLMPrecompile(LLM_PRECOMPILE).infer(llmReq);
        lastSynthesis = result;
        emit SynthesisStored(result);
    }

    function _buildCleanPrompt(string memory instr, string memory rawData)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(instr, "\n\nRelevant data:\n", rawData));
    }
}