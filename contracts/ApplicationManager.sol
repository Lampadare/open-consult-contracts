// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./FundingsManager.sol";

library ApplicationManager {
    using FundingsManager for FundingsManager.Fundings;
    using FundingsManager for FundingsManager.Fundings[];

    struct Application {
        // Description of the application
        string metadata;
        address applicant;
        bool accepted;
        FundingsManager.Fundings enrolStake;
        // Parent Project (contains IDs)
        uint256 parentProject;
    }
}
