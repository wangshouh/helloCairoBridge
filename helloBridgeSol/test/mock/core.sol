// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract Core {

	mapping(bytes32 => uint256) public l2ToL1Messages;
	mapping(bytes32 => uint256) public l1ToL2Messages;
	mapping(bytes32 => uint256) public l1ToL2MessageCancellations;

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

	function getL1ToL2MsgHash(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload,
        uint256 nonce
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    uint256(uint160(msg.sender)),
                    toAddress,
                    nonce,
                    selector,
                    payload.length,
                    payload
                )
            );
    }

	function sendMessageToL2(
	    uint256 toAddress,
	    uint256 selector,
	    uint256[] calldata payload
	) external payable returns (bytes32, uint256) {
	    require(msg.value > 0, "L1_MSG_FEE_MUST_BE_GREATER_THAN_0");
	    uint256 nonce = 1;
	    // emit LogMessageToL2(msg.sender, toAddress, selector, payload, nonce, msg.value);
	    bytes32 msgHash = getL1ToL2MsgHash(toAddress, selector, payload, nonce);
	    // Note that the inclusion of the unique nonce in the message hash implies that
	    // l1ToL2Messages()[msgHash] was not accessed before.
	    l1ToL2Messages[msgHash] = msg.value + 1;
	    return (msgHash, nonce);
	}

	function startL1ToL2MessageCancellation(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload,
        uint256 nonce
    ) external returns (bytes32) {
        // emit MessageToL2CancellationStarted(msg.sender, toAddress, selector, payload, nonce);
        bytes32 msgHash = getL1ToL2MsgHash(toAddress, selector, payload, nonce);
        uint256 msgFeePlusOne = l1ToL2Messages[msgHash];
        require(msgFeePlusOne > 0, "NO_MESSAGE_TO_CANCEL");
        l1ToL2MessageCancellations[msgHash] = block.timestamp;
        return msgHash;
    }
}