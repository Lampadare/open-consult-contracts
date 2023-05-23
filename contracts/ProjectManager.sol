// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./CampaignManager.sol";
import "./TaskManager.sol";
import "./FundingsManager.sol";
import "./Utilities.sol";

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

    // Check is project worker by address ✅
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

    // Overloading for memory project ✅
    function checkIsProjectWorker(
        Project memory _project,
        address _worker
    ) external pure returns (bool) {
        for (uint256 i = 0; i < _project.workers.length; i++) {
            if (_project.workers[i] == _worker) {
                return true;
            }
        }
        return false;
    }

    // Check msg.sender is project worker ✅
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

    // // Check fast forward status
    // function checkFastForwardStatus(
    //     Project memory _project,
    //     CampaignManager.Campaign memory _campaign
    // ) external pure returns (bool) {
    //     uint256 ownerVotes = 0;
    //     uint256 workerVotes = 0;
    //     uint256 acceptorVotes = 0;
    //     bool isProjectWorker = false;

    //     // Loop through fast forward votes
    //     for (uint256 i = 0; i < _project.fastForward.length; i++) {
    //         // Check if the voter is a worker
    //         for (uint256 j = 0; j < _project.workers.length; j++) {
    //             if (_project.workers[i] == _project.fastForward[i].voter) {
    //                 isProjectWorker = true;
    //             }
    //         }
    //         // If the voter is a worker and voted yes
    //         if (isProjectWorker && _project.fastForward[i].vote) {
    //             workerVotes++;
    //         } else {
    //             return false;
    //         }
    //         if (
    //             CampaignManager.checkIsCampaignOwner(
    //                 _campaign,
    //                 _project.fastForward[i].voter
    //             ) && _project.fastForward[i].vote
    //         ) {
    //             ownerVotes++;
    //         }
    //         if (
    //             CampaignManager.checkIsCampaignAcceptor(
    //                 _campaign,
    //                 _project.fastForward[i].voter
    //             ) && _project.fastForward[i].vote
    //         ) {
    //             acceptorVotes++;
    //         }
    //     }

    //     return
    //         ownerVotes > 0 &&
    //         acceptorVotes > 0 &&
    //         _project.workers.length <= workerVotes;
    // }

    // // Adjust lateness before stage
    // function updateProjectStatus(
    //     Project storage _project,
    //     CampaignManager.Campaign storage _campaign,
    //     TaskManager.Task storage _task
    // ) external {
    //     // GOING INTO STAGE 🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹
    //     if (_project.status == ProjectManager.ProjectStatus.Settled) {
    //         // Check to stage conditions
    //         bool currentStatusValid = _project.status ==
    //             ProjectManager.ProjectStatus.Settled;
    //         bool projectHasWorkers = _project.workers.length > 0;
    //         bool inStagePeriod = block.timestamp >=
    //             _project.nextMilestone.startStageTimestamp;

    //         // For fast forward
    //         bool stillInSettledPeriod = block.timestamp <
    //             _project.nextMilestone.startStageTimestamp;

    //         // All conditions must be true to go to stage
    //         bool toStage = (currentStatusValid &&
    //             projectHasWorkers &&
    //             inStagePeriod);
    //         bool toStageFastForward = (currentStatusValid &&
    //             projectHasWorkers &&
    //             stillInSettledPeriod &&
    //             ProjectManager.checkFastForwardStatus(_project, _campaign));

    //         if (toStageFastForward) {
    //             // Ensure all tasks have workers
    //             require(_task.worker != address(0), "E49");
    //             // update project status
    //             _project.status = ProjectManager.ProjectStatus.Stage;
    //             // delete all votes
    //             delete _project.fastForward;
    //             return;
    //         } else if (toStage) {
    //             // adjust lateness
    //             uint256 lateness = 0;
    //             // If we are late, add lateness to all tasks and nextmilestone
    //             if (
    //                 block.timestamp > _project.nextMilestone.startStageTimestamp
    //             ) {
    //                 lateness =
    //                     block.timestamp -
    //                     _project.nextMilestone.startStageTimestamp;
    //             }
    //             if (!_task.closed) {
    //                 _task.deadline += lateness; // add lateness to deadline
    //             }
    //             // add lateness to nextmilestone
    //             _project.nextMilestone.startGateTimestamp += lateness;
    //             _project.nextMilestone.startSettledTimestamp += lateness;
    //             // update project status
    //             _project.status = ProjectManager.ProjectStatus.Stage;
    //             // delete all votes
    //             delete _project.fastForward;
    //             return;
    //         }
    //     }
    //     // GOING INTO GATE 🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹
    //     else if (_project.status == ProjectManager.ProjectStatus.Stage) {
    //         // For standard conditions
    //         bool currentStatusValid = _project.status ==
    //             ProjectManager.ProjectStatus.Stage;
    //         bool inGatePeriod = block.timestamp >=
    //             _project.nextMilestone.startGateTimestamp;

    //         // For fast forward
    //         bool stillInStagePeriod = block.timestamp <
    //             _project.nextMilestone.startGateTimestamp;

    //         // Going to gate
    //         bool toGate = (currentStatusValid && inGatePeriod);
    //         // Fast forward to gate
    //         bool toGateFastForward = (currentStatusValid &&
    //             stillInStagePeriod &&
    //             ProjectManager.checkFastForwardStatus(_project, _campaign));

    //         if (toGateFastForward) {
    //             require(
    //                 _task.submission.status !=
    //                     TaskManager.SubmissionStatus.None,
    //                 "E50"
    //             );
    //             // update project status
    //             _project.status = ProjectManager.ProjectStatus.Gate;
    //             // delete all votes
    //             delete _project.fastForward;
    //             return;
    //         } else if (toGate) {
    //             // update project status
    //             _project.status = ProjectManager.ProjectStatus.Gate;
    //             // delete all votes
    //             delete _project.fastForward;
    //             return;
    //         }
    //     }
    // }

    // Worker dropout function ✅
    function workerDropOut(
        Project storage _project,
        Application storage _application,
        uint256 applicationId
    ) external {
        // Ensure sender is a worker
        bool isSenderProjectWorker = false;
        for (uint256 i = 0; i < _project.workers.length; i++) {
            if (_project.workers[i] == msg.sender) {
                isSenderProjectWorker = true;
                break;
            }
        }

        // Ensure project status is not stage
        require(
            _project.status != ProjectManager.ProjectStatus.Stage &&
                isSenderProjectWorker,
            "E28"
        );
        // Find worker's application, ensure it was accepted and not refunded
        require(
            _application.applicant == msg.sender &&
                !_application.enrolStake.fullyRefunded &&
                _application.accepted
        );
        // Remove worker from project
        Utilities.deleteItemInAddressArray(msg.sender, _project.workers);
        // Add Worker to pastWorkers in project
        _project.pastWorkers.push(msg.sender);
        // Refund stake in application
        _application.enrolStake.amountUsed = _application.enrolStake.funding;
        _application.enrolStake.fullyRefunded = true;
        payable(msg.sender).transfer(_application.enrolStake.funding);
        Utilities.deleteItemInUintArray(applicationId, _project.applications); //-> Get rid of refunded application
    }

    // Fire worker function ✅
    function fireWorker(
        Project storage _project,
        Application storage _application,
        uint256 applicationId
    ) external {
        // Ensure sender is a worker
        bool isSenderProjectWorker = false;
        for (uint256 i = 0; i < _project.workers.length; i++) {
            if (_project.workers[i] == _application.applicant) {
                isSenderProjectWorker = true;
                break;
            }
        }

        // Ensure project status is not stage
        require(
            _project.status != ProjectManager.ProjectStatus.Stage ==
                isSenderProjectWorker,
            "E30"
        );
        // Find worker's application, ensure it was accepted and not refunded
        require(
            !_application.enrolStake.fullyRefunded && _application.accepted
        );
        // Remove worker from project
        Utilities.deleteItemInAddressArray(
            _application.applicant,
            _project.workers
        );
        // Add Worker to pastWorkers in project
        _project.pastWorkers.push(_application.applicant);
        // Refund stake in application
        _application.enrolStake.amountUsed = _application.enrolStake.funding;
        _application.enrolStake.fullyRefunded = true;
        payable(msg.sender).transfer(_application.enrolStake.funding);
        Utilities.deleteItemInUintArray(applicationId, _project.applications); //-> Get rid of refunded application
    }

    function updateProjectRewardsConditions(
        Project storage _project,
        uint256 taskSubmissionDecisionDisputeTime
    ) external view returns (bool) {
        bool atGate = _project.status == ProjectManager.ProjectStatus.Gate ||
            _project.status == ProjectManager.ProjectStatus.Closed;
        bool afterCleanup = block.timestamp >
            _project.nextMilestone.startGateTimestamp +
                taskSubmissionDecisionDisputeTime;

        // Ensure all conditions are met
        return atGate && afterCleanup;
    }
}
