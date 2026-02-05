// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Counter {
    uint256 public count;

    event CountChanged(uint256 newCount);

    function increment() public {
        count += 1;
        emit CountChanged(count);
    }

    function decrement() public {
        count -= 1;
        emit CountChanged(count);
    }

    function getCount() public view returns (uint256) {
        return count;
    }
}
