// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Minimal Safe contracts for deployment

/// @title SafeL2 - L2 optimized Safe singleton
contract SafeL2 {
    address[] public owners;
    uint256 public threshold;
    uint256 public nonce;

    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;
    bytes32 private constant SAFE_TX_TYPEHASH = 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8;

    event SafeSetup(address indexed initiator, address[] owners, uint256 threshold);
    event ExecutionSuccess(bytes32 txHash);
    event ExecutionFailure(bytes32 txHash);

    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address, bytes calldata, address, address, uint256, address payable
    ) external {
        require(threshold == 0, "Already initialized");
        require(_owners.length >= _threshold && _threshold > 0, "Invalid threshold");

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            owners.push(_owners[i]);
        }
        threshold = _threshold;
        emit SafeSetup(msg.sender, _owners, _threshold);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function isOwner(address owner) public view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) return true;
        }
        return false;
    }

    function getThreshold() public view returns (uint256) {
        return threshold;
    }

    receive() external payable {}
}

/// @title SafeProxyFactory - Factory to create Safe proxies
contract SafeProxyFactory {
    event ProxyCreation(address indexed proxy, address singleton);

    function createProxyWithNonce(
        address singleton,
        bytes memory initializer,
        uint256 saltNonce
    ) public returns (address proxy) {
        bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), saltNonce));
        bytes memory deploymentData = abi.encodePacked(
            type(SafeProxy).creationCode,
            uint256(uint160(singleton))
        );

        assembly {
            proxy := create2(0, add(deploymentData, 0x20), mload(deploymentData), salt)
        }
        require(proxy != address(0), "Create2 failed");

        if (initializer.length > 0) {
            assembly {
                if eq(call(gas(), proxy, 0, add(initializer, 0x20), mload(initializer), 0, 0), 0) {
                    revert(0, 0)
                }
            }
        }
        emit ProxyCreation(proxy, singleton);
    }

    function proxyCreationCode() public pure returns (bytes memory) {
        return type(SafeProxy).creationCode;
    }
}

/// @title SafeProxy - Proxy contract for Safe
contract SafeProxy {
    address internal singleton;

    constructor(address _singleton) {
        singleton = _singleton;
    }

    fallback() external payable {
        assembly {
            let _singleton := sload(0)
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), _singleton, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if eq(success, 0) { revert(0, returndatasize()) }
            return(0, returndatasize())
        }
    }

    receive() external payable {}
}

/// @title MultiSend - Allows batching multiple transactions
contract MultiSend {
    function multiSend(bytes memory transactions) public payable {
        assembly {
            let length := mload(transactions)
            let i := 0x20
            for { } lt(i, length) { } {
                let operation := shr(0xf8, mload(add(transactions, i)))
                let to := shr(0x60, mload(add(transactions, add(i, 0x01))))
                let value := mload(add(transactions, add(i, 0x15)))
                let dataLength := mload(add(transactions, add(i, 0x35)))
                let data := add(transactions, add(i, 0x55))
                let success := 0
                switch operation
                case 0 { success := call(gas(), to, value, data, dataLength, 0, 0) }
                case 1 { success := delegatecall(gas(), to, data, dataLength, 0, 0) }
                if eq(success, 0) { revert(0, 0) }
                i := add(i, add(0x55, dataLength))
            }
        }
    }
}

/// @title MultiSendCallOnly - MultiSend that only allows calls (no delegatecall)
contract MultiSendCallOnly {
    function multiSend(bytes memory transactions) public payable {
        assembly {
            let length := mload(transactions)
            let i := 0x20
            for { } lt(i, length) { } {
                let operation := shr(0xf8, mload(add(transactions, i)))
                if eq(operation, 1) { revert(0, 0) } // No delegatecall
                let to := shr(0x60, mload(add(transactions, add(i, 0x01))))
                let value := mload(add(transactions, add(i, 0x15)))
                let dataLength := mload(add(transactions, add(i, 0x35)))
                let data := add(transactions, add(i, 0x55))
                let success := call(gas(), to, value, data, dataLength, 0, 0)
                if eq(success, 0) { revert(0, 0) }
                i := add(i, add(0x55, dataLength))
            }
        }
    }
}

/// @title CompatibilityFallbackHandler - Fallback handler for Safe
contract CompatibilityFallbackHandler {
    function isValidSignature(bytes32 _hash, bytes calldata _signature) external view returns (bytes4) {
        // Simplified - in production would verify Safe signatures
        return 0x1626ba7e;
    }

    function getMessageHash(bytes memory message) public view returns (bytes32) {
        return keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), address(this), keccak256(message)));
    }

    function isValidSignature(bytes calldata _data, bytes calldata _signature) public view returns (bytes4) {
        return 0x20c13b0b;
    }

    function getModules() external pure returns (address[] memory) {
        return new address[](0);
    }

    function simulate(address targetContract, bytes calldata calldataPayload) external returns (bytes memory) {
        (bool success, bytes memory response) = targetContract.call(calldataPayload);
        require(success, "Simulation failed");
        return response;
    }
}

/// @title CreateCall - Helper to create contracts from Safe
contract CreateCall {
    event ContractCreation(address indexed newContract);

    function performCreate(uint256 value, bytes memory deploymentData) public returns (address newContract) {
        assembly {
            newContract := create(value, add(deploymentData, 0x20), mload(deploymentData))
        }
        require(newContract != address(0), "Create failed");
        emit ContractCreation(newContract);
    }

    function performCreate2(uint256 value, bytes memory deploymentData, bytes32 salt) public returns (address newContract) {
        assembly {
            newContract := create2(value, add(deploymentData, 0x20), mload(deploymentData), salt)
        }
        require(newContract != address(0), "Create2 failed");
        emit ContractCreation(newContract);
    }
}

/// @title SignMessageLib - Helper for signing messages
contract SignMessageLib {
    event SignMsg(bytes32 indexed msgHash);

    mapping(bytes32 => uint256) public signedMessages;

    function signMessage(bytes calldata _data) external {
        bytes32 msgHash = keccak256(_data);
        signedMessages[msgHash] = 1;
        emit SignMsg(msgHash);
    }
}
