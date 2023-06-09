// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./mock/core.sol";
import "../src/BridgeERC20.sol";

contract CounterTest is Test {
    using stdStorage for StdStorage;

    Core public core;
    BridgeERC20 public token_code;
    address public targetAddr;

    function setUp() public {
        core = new Core();
        uint256 L2Address = 0x03df9e4bb7dbee67fbfb50d5e1e8205df55c7b85789b1eb0dca618c390c0ffee;
        token_code = new BridgeERC20("BRIDGE", "BE", 18, address(core), L2Address);

        bytes memory code = address(token_code).code;
        targetAddr = address(0xAFD48f565e1aC63f3e547227c9AD5243990f3D40);
        vm.etch(targetAddr, code);

        uint256 slot = stdstore
            .target(targetAddr)
            .sig("starkNetAddress()")
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedCore = bytes32(abi.encode(address(core)));
        vm.store(targetAddr, loc, mockedCore);
    }

    function test_init() public {
        assertEq(BridgeERC20(targetAddr).starkNetAddress(), address(core));
    }

    function test_despoitFromL2() public {
        uint256 fromAddress = 0x03df9e4bb7dbee67fbfb50d5e1e8205df55c7b85789b1eb0dca618c390c0ffee;
        uint256[] memory payload = new uint256[](3);
        payload[0] = 98643737269556690607045493661323739746101663068;
        payload[1] = 100;
        BridgeERC20(targetAddr).despoitFromL2(fromAddress, payload);

        address receiver = address(98643737269556690607045493661323739746101663068);
        assertEq(BridgeERC20(targetAddr).balanceOf(receiver), 100);
    }

    function test_FailDesposit() public {
        uint256 fromAddress = 0x03df9e4bb7dbee67fbfb50d5e1e8205df55c7b85789b1eb0dca618c390c0ffee;
        uint256[] memory payload = new uint256[](3);
        payload[0] = 98643737269556690607045493661323739746101663068;
        payload[1] = 100;   

        vm.expectRevert("INVALID_MESSAGE_TO_CONSUME");
        token_code.despoitFromL2(fromAddress, payload);
    }

    function test_transferToL2() public {
        token_code.mint(1 ether);
        uint256 toAddress = 0x04df9e4bb7dbee67fbfb50d5e1e8205df55c7b85789b1eb0dca618c390c0ffee;
        uint256 amount = 1 ether;
        uint256 nonce = token_code.transferToL2{value: 1 ether}(toAddress, amount);
        assertEq(token_code.nonceValue(nonce, address(this)), amount);
    }

    function test_FailstartCancel() public {
        token_code.mint(1 ether);
        uint256 toAddress = 0x04df9e4bb7dbee67fbfb50d5e1e8205df55c7b85789b1eb0dca618c390c0ffee;
        uint256 amount = 1 ether;
        token_code.transferToL2{value: 1 ether}(toAddress, amount);
        vm.expectRevert("NONCE_NOT_EXIST");
        token_code.startCancel(toAddress, 2);
    }

    function test_startCancel() public {
        token_code.mint(1 ether);
        uint256 toAddress = 0x04df9e4bb7dbee67fbfb50d5e1e8205df55c7b85789b1eb0dca618c390c0ffee;
        uint256 amount = 1 ether;
        uint256 nonce = token_code.transferToL2{value: 1 ether}(toAddress, amount);
        token_code.startCancel(toAddress, nonce);
    }
}