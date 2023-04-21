// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract Core {

	mapping(bytes32 => uint256) public l2ToL1Messages;

	function consumeMessageFromL2(uint256 fromAddress, uint256[] calldata payload)
	    external
	    returns (bytes32)
	{
		l2ToL1Messages[0x829b7b9b220945a1e3c40d04eb2b6c38b0ee7ff6f54049bbb4b9ea87d021b21a] = 1;

	    bytes32 msgHash = keccak256(
	        abi.encodePacked(fromAddress, uint256(uint160(msg.sender)), payload.length, payload)
	    );

	    require(l2ToL1Messages[msgHash] > 0, "INVALID_MESSAGE_TO_CONSUME");
	    // emit ConsumedMessageToL1(fromAddress, msg.sender, payload);
	    l2ToL1Messages[msgHash] -= 1;
	    return msgHash;
	}
}