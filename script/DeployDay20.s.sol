// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../CounterContract.sol";
import "../RecursiveAgentTrigger.sol";

contract DeployDay20 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        CounterContract counter = new CounterContract();
        RecursiveAgentTrigger trigger = new RecursiveAgentTrigger();
        
        vm.stopBroadcast();
    }
}
