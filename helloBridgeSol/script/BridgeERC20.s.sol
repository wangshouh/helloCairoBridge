// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/BridgeERC20.sol";

contract BridgeScript is Script {
    function run() public returns (BridgeERC20 token) {
        vm.startBroadcast();
        uint256 L2Address = 0x01333558b36dcba8bfdaf329a20a595958bfa2c97aa0332df4350199b740228f;
        address core = 0xde29d060D45901Fb19ED6C6e959EB22d8626708e;
        token = new BridgeERC20("BRIDGE", "BE", 18, core, L2Address);
        vm.stopBroadcast();
    }
}
