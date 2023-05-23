// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./CampaignManager.sol";
import "./TaskManager.sol";
import "./FundingsManager.sol";

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

    struct Application {
        // Description of the application
        string metadata;
        address applicant;
        bool accepted;
        FundingsManager.Fundings enrolStake;
        // Parent Project (contains IDs)
        uint256 parentProject;
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

    function checkIsProjectWorker(
        Project storage _project,
        address _worker
    ) external view returns (bool) {
        for (uint256 i = 0; i < _project.workers.length; i++) {
            if (_project.workers[i] == _worker) {
                return true;
            }
        }
        return false;
    }

    function checkIsProjectWorker(
        Project storage _project
    ) external view returns (bool) {
        for (uint256 i = 0; i < _project.workers.length; i++) {
            if (_project.workers[i] == msg.sender) {
                return true;
            }
        }
        return false;
    }

    // Enrol to project as worker when no application is required ✅
    function workerEnrolNoApplication(
        Project storage _project,
        CampaignManager.Campaign storage _campaign,
        Application storage _application,
        uint256 _id,
        uint256 _applicationCount
    ) external {
        require(!_project.applicationRequired, "E33");

        // Creates application to deal with stake

        _application.metadata = "_";
        _application.applicant = msg.sender;
        _application.accepted = true;
        _application.enrolStake.funder = payable(msg.sender);
        _application.enrolStake.funding = msg.value;
        _application.enrolStake.amountUsed = 0;
        _application.enrolStake.fullyRefunded = false;
        _application.parentProject = _id;

        _project.applications.push(_applicationCount);

        _project.workers.push(msg.sender);
        _campaign.allTimeStakeholders.push(payable(msg.sender));
        _campaign.workers.push(payable(msg.sender));
    }

    // Enrol to project as worker when application is required ✅
    function applyToProject(
        Project storage _project,
        Application storage _application,
        string memory _metadata,
        uint256 _id,
        uint256 _applicationCount
    ) external {
        require(_project.applicationRequired, "E34");

        // Creates application to deal with stake

        _application.metadata = _metadata;
        _application.applicant = msg.sender;
        _application.accepted = false;
        _application.enrolStake.funder = payable(msg.sender);
        _application.enrolStake.funding = msg.value;
        _application.enrolStake.amountUsed = 0;
        _application.enrolStake.fullyRefunded = false;
        _application.parentProject = _id;

        _project.applications.push(_applicationCount);
    }
}
