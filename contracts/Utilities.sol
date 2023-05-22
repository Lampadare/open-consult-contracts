// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

library Utilities {
    // Returns maximum of two numbers ✅
    function max(uint256 a, uint256 b) external pure returns (uint) {
        return a > b ? a : b;
    }

    // Pattern for deleting stuff from uint arrays by uint256 ID ✅
    function deleteItemInUintArray(
        uint256 _ItemID,
        uint256[] storage _array
    ) external {
        uint256 i = 0;
        while (i < _array.length) {
            if (_array[i] == _ItemID) {
                _array[i] = _array[_array.length - 1];
                _array.pop();
                return;
            }
            i++;
        }
        // Throw an error if the item was not found.
        revert("Item not found");
    }

    // Pattern for deleting stuff from address arrays by address ✅
    function deleteItemInAddressArray(
        address _ItemAddress,
        address[] storage _array
    ) external {
        uint256 i = 0;
        while (i < _array.length) {
            if (_array[i] == _ItemAddress) {
                _array[i] = _array[_array.length - 1];
                _array.pop();
                return;
            }
            i++;
        }
        // Throw an error if the item was not found.
        revert("Item not found");
    }

    // Pattern for deleting stuff from payable address arrays by address ✅
    function deleteItemInPayableAddressArray(
        address payable _ItemAddress,
        address payable[] storage _array
    ) external {
        uint256 i = 0;
        while (i < _array.length) {
            if (_array[i] == _ItemAddress) {
                _array[i] = _array[_array.length - 1];
                _array.pop();
                return;
            }
            i++;
        }
        // Throw an error if the item was not found.
        revert("Item not found");
    }
}
