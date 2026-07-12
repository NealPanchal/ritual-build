// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../HTTPPrecompileTest.sol";

contract HTTPPrecompileRunTest is Test {
    HTTPPrecompileTest public httpTest;
    address constant HTTP_PRECOMPILE = 0x0000000000000000000000000000000000000801;
    address constant RITUAL_WALLET   = 0x0000000000000000000000000000000000000100;

    function setUp() public {
        httpTest = new HTTPPrecompileTest();
    }

    function testRunAndExecute() public {
        console.log("-> Starting execution test...");
        
        uint256 fundAmount = 0.1 ether;
        uint256 lockDuration = 1 days;
        
        // Mock the RitualWallet deposit call
        vm.mockCall(
            RITUAL_WALLET,
            fundAmount,
            abi.encodeWithSignature("deposit(uint256)", lockDuration),
            ""
        );

        console.log("-> Funding RitualWallet with %s wei for lock duration %s", fundAmount, lockDuration);
        httpTest.fundWallet{value: fundAmount}(lockDuration);
        
        assertTrue(httpTest.walletFunded(), "Wallet should be funded");
        
        // 2. Fetch external data
        string memory testUrl = "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd";
        console.log("-> Fetching external data from URL: %s", testUrl);
        
        // Mock the HTTP Precompile fetch call
        IHTTPPrecompile.HTTPRequest memory req = IHTTPPrecompile.HTTPRequest({
            url: testUrl,
            method: "GET",
            headers: "",
            body: ""
        });
        string memory expectedResponse = string(abi.encodePacked("Simulated HTTP Response for: ", testUrl));
        
        vm.mockCall(
            HTTP_PRECOMPILE,
            abi.encodeWithSignature("fetch((string,string,string,string))", req),
            abi.encode(expectedResponse)
        );
        
        httpTest.fetchExternalData(testUrl);
        
        // 3. Verify the result
        string memory result = httpTest.lastFetchedData();
        console.log("-> Received response: %s", result);
        
        assertEq(result, expectedResponse, "Response should match mock");
        console.log("-> Execution successful!");
    }
}
