// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./FundingsManager.sol";
import "./ApplicationManager.sol";

library ProjectManager {
    struct Project {
        // Description of the project
        string metadata;
        // Contribution weight
        uint256 weight;
        uint256 reward;
        // Timestamps
        uint256 creationTime;
        Vote[] fastForward;
        NextMilestone nextMilestone;
        ProjectStatus status;
        // Workers & Applications
        bool applicationRequired;
        uint256[] applications;
        address[] workers;
        address[] pastWorkers;
        // Parent Campaign & Project (contains IDs)
        uint256 parentCampaign;
        uint256 parentProject;
        // Child Tasks & Projects (contains IDs)
        uint256[] childProjects;
        uint256[] childTasks;
    }

    struct NextMilestone {
        uint256 startStageTimestamp;
        uint256 startGateTimestamp;
        uint256 startSettledTimestamp;
    }

    struct Vote {
        address voter;
        bool vote;
    }

    enum ProjectStatus {
        Stage,
        Gate,
        Settled,
        Closed
    }
}
