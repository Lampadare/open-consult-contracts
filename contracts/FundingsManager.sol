// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

library FundingsManager {
    struct Fundings {
        address payable funder; // The address of the individual who contributed
        uint256 funding; // The amount of tokens the user contributed
        uint256 amountUsed; // The amount of tokens that have been paid out
        uint256 amountLocked; // The amount of tokens that have been locked
        bool fullyRefunded; // A boolean storing whether or not the contribution has been fully refunded or fully used
    }

    function fundLockAmount(
        Fundings[] storage _fundings,
        uint256 _expense
    ) external {
        uint256 expenseLoader = 0;

        // Loop through all fundings
        for (uint256 i = 0; i < _fundings.length; i++) {
            // If the funding has not been fully refunded
            if (!_fundings[i].fullyRefunded) {
                // Calculate the amount of tokens that should be locked
                uint256 remainingToLock = _expense - expenseLoader;
                // Calculate the effective balance of the funding
                uint256 effectiveBalanceFunding = _fundings[i].funding -
                    _fundings[i].amountUsed -
                    _fundings[i].amountLocked;
                // If the remaining amount to lock is more than the effective balance of the funding
                // Lock the entire effective balance of the funding
                if (remainingToLock >= effectiveBalanceFunding) {
                    _fundings[i].amountLocked += effectiveBalanceFunding;
                    expenseLoader += effectiveBalanceFunding;
                }
                // If the remaining amount to lock is less than the effective balance of the funding
                // Lock the remaining amount to lock
                else {
                    _fundings[i].amountLocked += remainingToLock;
                    expenseLoader = _expense;
                    return;
                }
            }
        }
    }

    // Unlock amounts of funds by going through each funding and unlocking until the expense is covered ✅
    function fundUnlockAmount(
        Fundings[] storage _fundings,
        uint256 _expense
    ) external {
        uint256 expenseLoader = 0;

        // If the expense is to be unlocked, remove it from the amountLocked of the fundings (in reverse order)
        for (uint256 i = _fundings.length; i > 0; i--) {
            if (!_fundings[i - 1].fullyRefunded) {
                uint256 remainingToUnlock = _expense - expenseLoader;

                // Locked balance of this specific funding
                uint256 lockedFundingBalance = _fundings[i - 1].amountLocked;

                // If the locked balance of the funding is less than the expense loader, unlock the whole locked balance
                if (remainingToUnlock >= lockedFundingBalance) {
                    _fundings[i - 1].amountLocked = 0;
                    expenseLoader += lockedFundingBalance;
                } else {
                    _fundings[i - 1].amountLocked -= remainingToUnlock;
                    expenseLoader = _expense;
                    return;
                }
            }
        }
    }

    // Use amounts of funds by going through each funding and using until the expense is covered ✅
    function fundUseAmount(
        Fundings[] storage _fundings,
        uint256 _expense
    ) external {
        uint256 expenseLoader = 0;

        // If the expense is to be used, add it to the amountUsed of the fundings
        // loop over all the non fullyRefunded fundings and add a part to amountUsed which is proportional to how much the funding is
        for (uint256 i = 0; i < _fundings.length; i++) {
            if (!_fundings[i].fullyRefunded) {
                uint256 remainingToUse = _expense - expenseLoader;

                // Locked balance of this specific funding
                uint256 lockedFundingBalance = _fundings[i].amountLocked;

                // If what is remaining to be used is more than the locked funding balance, use the whole locked balance
                if (remainingToUse >= lockedFundingBalance) {
                    _fundings[i].amountUsed += lockedFundingBalance;
                    _fundings[i].amountLocked = 0;
                    _fundings[i].fullyRefunded = true;
                    expenseLoader += lockedFundingBalance;
                } else {
                    _fundings[i].amountUsed += remainingToUse;
                    _fundings[i].amountLocked -= remainingToUse;
                    expenseLoader = _expense;
                    return;
                }
            }
        }
    }
}
