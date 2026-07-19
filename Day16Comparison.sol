// AGENT-SCAFFOLDED VERSION — better error handling
function fetchExternalData(string calldata url) external {
    require(walletFunded, "fund wallet first");

    try IHTTPPrecompile(HTTP_PRECOMPILE).fetch(
        _buildRequest(url)
    ) returns (string memory response) {
        require(bytes(response).length > 0, "empty response");
        lastFetchedData = response;
        emit FetchSucceeded(response);
    } catch Error(string memory reason) {
        emit FetchFailed(reason);
        revert(reason);
    } catch {
        emit FetchFailed("unknown error");
        revert("HTTP fetch failed");
    }
}

// MY HAND-BUILT VERSION — tighter gas, no try/catch overhead
function _storeResult(string memory result) internal {
    lastSynthesis = result;
    emit SynthesisStored(result);
}
