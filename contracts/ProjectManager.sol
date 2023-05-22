// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./CampaignManager.sol";
import "./TaskManager.sol";
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
        Closed,
        Stage,
        Gate,
        Settled
    }

    // Write Functions
    // Project Creation Function ✅
    function makeProject(
        Project storage _project,
        string memory _metadata,
        // uint256 _deadline,
        bool _applicationRequired,
        uint256 _parentCampaignId
    ) external {
        // Populate project
        _project.metadata = _metadata;
        _project.creationTime = block.timestamp;
        _project.status = ProjectManager.ProjectStatus.Gate;
        _project.nextMilestone = ProjectManager.NextMilestone(0, 0, 0);
        _project.applicationRequired = _applicationRequired;

        // In THIS project being created, set the parent campaign and project
        _project.parentCampaign = _parentCampaignId;

        // // Open campaigns don't require applications
        // if (parentCampaign.style == CampaignManager.CampaignStyle.Open) {
        //     project.applicationRequired = false;
        // } else {
        //     project.applicationRequired = _applicationRequired;
        // }
    }

    // Find the status project should be at based on the current time ✅
    function whatStatusProjectShouldBeAt(
        Project storage _project
    ) external view returns (ProjectStatus) {
        require(_project.status != ProjectManager.ProjectStatus.Closed, "E37");
        if (block.timestamp < _project.nextMilestone.startStageTimestamp) {
            return ProjectStatus.Settled;
        } else if (
            block.timestamp < _project.nextMilestone.startGateTimestamp
        ) {
            return ProjectStatus.Stage;
        } else if (
            block.timestamp < _project.nextMilestone.startSettledTimestamp
        ) {
            return ProjectStatus.Gate;
        } else {
            return ProjectStatus.Settled;
        }
    }

    // To Stage Conditions Function ✅
    function toStageConditionsWithNotClosedTasks(
        Project storage _project,
        TaskManager.Task[] memory _notClosedTasks
    ) external view returns (bool) {
        bool currentStatusValid = _project.status ==
            ProjectManager.ProjectStatus.Settled;
        bool projectHasWorkers = _project.workers.length > 0;
        bool allTasksHaveWorkers = true;
        bool inStagePeriod = block.timestamp >=
            _project.nextMilestone.startStageTimestamp;

        // Ensure all tasks have workers
        for (uint256 i = 0; i < _notClosedTasks.length; i++) {
            if (_notClosedTasks[i].worker == address(0)) {
                allTasksHaveWorkers = false;
                return false;
            }
        }

        // All conditions must be true to go to stage
        return
            allTasksHaveWorkers &&
            currentStatusValid &&
            projectHasWorkers &&
            inStagePeriod;
    }
}
