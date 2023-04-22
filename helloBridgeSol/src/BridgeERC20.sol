// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./interfaces/IStarknetMessaging.sol";

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
contract BridgeERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    event MessageHash(bytes32 indexed msgHash);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                               Bridge LOGIC
    //////////////////////////////////////////////////////////////*/

    address public starkNetAddress;

    uint256 public L2TokenAddress;

    mapping(uint256 => mapping(address => uint256)) public nonceValue;

    uint256 internal constant SELECTOR = 0x29d87c15de029f724fce9cf6a2aed131eda59233a02ec4e3bdd0520edee37e7;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _starkNetAddress,
        uint256 _l2Token
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        starkNetAddress = _starkNetAddress;
        L2TokenAddress = _l2Token;
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;

        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

    function mint(uint256 amount) external {
        totalSupply += amount;

        unchecked {
            balanceOf[msg.sender] += amount;
        }

        emit Transfer(address(0), msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                               Bridge LOGIC
    //////////////////////////////////////////////////////////////*/

    function payloadParese(uint256[] calldata payload) internal pure returns (address, uint256) {
        address receiver = address(uint160(payload[0]));
        uint256 amount = payload[2] << 128 | payload[1];
        return (receiver, amount);
    }

    function despoitFromL2(uint256 fromAddress, uint256[] calldata payload) external {
        IStarknetMessaging(starkNetAddress).consumeMessageFromL2(
            fromAddress,
            payload
        );
        (address receiver, uint256 amount) = payloadParese(payload);
        _mint(receiver, amount);
    }

    function generatePayload(
        uint256 L2Address, 
        uint256 amount
    ) internal pure returns (uint256[] memory payload) {
        payload = new uint256[](3);
        uint128 low = uint128(amount);
        uint128 high = uint128(amount >> 128);

        payload[0] = L2Address;
        payload[1] = low;
        payload[2] = high;
    }

    function transferToL2(uint256 L2Address, uint256 amount) payable external returns (uint256) {
        _burn(msg.sender, amount);
        uint256[] memory payload = generatePayload(L2Address, amount);

        (bytes32 msgHash,uint256 nonce) = IStarknetMessaging(starkNetAddress).sendMessageToL2{value: msg.value}(
            L2TokenAddress, SELECTOR, payload
        );

        emit MessageHash(msgHash);

        nonceValue[nonce][msg.sender] = amount;

        return nonce;
    }

    function startCancel(uint256 L2Address, uint256 nonce) external {
        uint256 amount = nonceValue[nonce][msg.sender];
        require(amount > 0, "NONCE_NOT_EXIST");
        uint256[] memory payload = generatePayload(L2Address, amount);
        IStarknetMessaging(starkNetAddress).startL1ToL2MessageCancellation(
            L2TokenAddress, SELECTOR, payload, nonce
        );
    }

    function cancel(uint256 L2Address, uint256 nonce) external {
        uint256 amount = nonceValue[nonce][msg.sender];
        require(amount > 0, "NONCE_NOT_EXIST");
        uint256[] memory payload = generatePayload(L2Address, amount);
        IStarknetMessaging(starkNetAddress).cancelL1ToL2Message(
            L2TokenAddress, SELECTOR, payload, nonce
        );
        nonceValue[nonce][msg.sender] = 0;
        _mint(msg.sender, amount);
    }
}