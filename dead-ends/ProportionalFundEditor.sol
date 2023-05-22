//BETTER SOLUTION BUT NEEDS CHECKS AND MODELLING -> no time
// Proportional Fund Locker Function, adds _expense to locked funds by splitting it
// into the different fundings of the campaign proportionally to their effective contributions 🧐
function fundLockAmount(
    uint256 _id,
    uint256 _expense
) internal isCampaignExisting(_id) isEffectiveBalanceMoreThanZero(_id) {
    Campaign storage campaign = campaigns[_id];
    uint256 currentEffectiveCampaignBalance = getEffectiveCampaignBalance(_id);

    // If the expense is to be locked, add it to the amountUsed of the fundings
    // loop over all the non fullyRefunded fundings and add a part to amountUsed which is proportional to how much the funding is
    for (uint256 i = 0; i < campaign.fundings.length; i++) {
        if (!campaign.fundings[i].fullyRefunded) {
            // Effective balance of this specific funding
            uint256 effectiveBalanceOfFunding = campaign.fundings[i].funding -
                campaign.fundings[i].amountUsed -
                campaign.fundings[i].amountLocked;

            // Fraction of the total effective campaign balance that this funding is
            uint256 fractionOfTotalEffectiveCampaignBalance = effectiveBalanceOfFunding /
                    currentEffectiveCampaignBalance;

            // Amount of the expense that should be used from this funding
            uint256 proportionalLockedAmount = _expense *
                fractionOfTotalEffectiveCampaignBalance;

            // Add the proportional locked amount to the amountLocked of the funding
            campaign.fundings[i].amountLocked += proportionalLockedAmount;
        }
    }
}

// Proportional Fund User Function, adds _expense to used funds by splitting it
// into the different fundings of the campaign proportionally to their effective contributions 🧐
function fundUseLockedAmount(
    uint256 _id,
    uint256 _expense
) internal isCampaignExisting(_id) isLockedBalanceMoreThanZero(_id) {
    Campaign storage campaign = campaigns[_id];
    uint256 currentLockedCampaignBalance = getCampaignLockedRewards(_id);

    // If the expense is to be used, add it to the amountUsed of the fundings
    // loop over all the non fullyRefunded fundings and add a part to amountUsed which is proportional to how much the funding is
    for (uint256 i = 0; i < campaign.fundings.length; i++) {
        if (!campaign.fundings[i].fullyRefunded) {
            // Locked balance of this specific funding
            uint256 lockedFundingBalance = campaign.fundings[i].amountLocked;

            // Fraction of the total locked campaign balance that this funding is
            uint256 fractionOfTotalLockedCampaignBalance = lockedFundingBalance /
                    currentLockedCampaignBalance;

            // Amount of the expense that should be used from this funding
            uint256 proportionalUseAmount = _expense *
                fractionOfTotalLockedCampaignBalance;

            // Add the proportional used amount to the amountUsed of the funding
            campaign.fundings[i].amountUsed += proportionalUseAmount;
            // Remove the proportional locked amount from the amountLocked of the funding
            campaign.fundings[i].amountLocked -= proportionalUseAmount;

            if (
                campaign.fundings[i].amountUsed == campaign.fundings[i].funding
            ) {
                campaign.fundings[i].fullyRefunded = true;
            }
        }
    }
}

// Proportional Fund Unlocker Function, removes _expense from locked funds by splitting it
// into the different fundings of the campaign proportionally to their effective contributions 🧐
function fundUnlockAmount(
    uint256 _id,
    uint256 _expense
) internal isCampaignExisting(_id) isLockedBalanceMoreThanZero(_id) {
    Campaign storage campaign = campaigns[_id];
    uint256 currentLockedCampaignBalance = getCampaignLockedRewards(_id);

    // If the expense is to be unlocked, remove it from the amountLocked of the fundings
    // loop over all the non fullyRefunded fundings and remove a part from amountLocked which is proportional to how much the funding is
    for (uint256 i = 0; i < campaign.fundings.length; i++) {
        if (!campaign.fundings[i].fullyRefunded) {
            // Locked balance of this specific funding
            uint256 lockedFundingBalance = campaign.fundings[i].amountLocked;

            // Fraction of the total locked campaign balance that this funding is
            uint256 fractionOfTotalLockedCampaignBalance = lockedFundingBalance /
                    currentLockedCampaignBalance;

            // Amount of the expense that should be unlocked from this funding
            uint256 proportionalUnlockAmount = _expense *
                fractionOfTotalLockedCampaignBalance;

            // Remove the proportional unlocked amount from the amountLocked of the funding
            campaign.fundings[i].amountLocked -= proportionalUnlockAmount;
        }
    }
}
