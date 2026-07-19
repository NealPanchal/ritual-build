/// @dev PLACEHOLDER — confirm exact function names/params against
///      ritual-dapp-scheduler before wiring. Not yet integrated into
///      FetchAndSynthesize.sol. This is prep only, added day 17 morning
///      after reading the docs, wiring happens once guarantees are clear.
interface ISchedulerPrecompile {
    /// @notice Register a recurring call to a target function.
    /// @param target Contract to call on each trigger.
    /// @param selector Function selector to invoke.
    /// @param interval Seconds between triggers — confirm units/precision.
    /// @return jobId Identifier for managing/cancelling this schedule.
    function registerRecurring(
        address target,
        bytes4 selector,
        uint256 interval
    ) external returns (uint256 jobId);

    /// @notice Cancel a previously registered recurring job.
    function cancel(uint256 jobId) external;

    // Open questions to resolve from docs before wiring:
    // - Exact-time trigger or best-effort/"eventually" semantics?
    // - What happens on a failed execution — retry, skip, or halt the schedule?
    // - Does a failed target call consume RitualWallet balance anyway?
}
