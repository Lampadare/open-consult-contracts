// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./CampaignManager.sol";
import "./ProjectManager.sol";
import "./TaskManager.sol";
import "./ApplicationManager.sol";
import "./FundingsManager.sol";
import "./Utilities.sol";

contract StandardCampaign {
    /// ⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️
    /// STRUCTS DECLARATIONS
    using Utilities for uint256[];
    using Utilities for address[];
    using Utilities for address payable[];
    using FundingsManager for FundingsManager.Fundings;
    using FundingsManager for FundingsManager.Fundings[];
    using CampaignManager for CampaignManager.Campaign;
    using ProjectManager for ProjectManager.Project;
    using TaskManager for TaskManager.Task;
    using ApplicationManager for ApplicationManager.Application;

    // Mapping of campaign IDs to campaigns, IDs are numbers starting from 0
    mapping(uint256 => CampaignManager.Campaign) public campaigns;
    uint256 public campaignCount = 0;

    // Mapping of project IDs to projects, IDs are numbers starting from 0
    mapping(uint256 => ProjectManager.Project) public projects;
    uint256 public projectCount = 0;

    // Mapping of task IDs to tasks, IDs are numbers starting from 0
    mapping(uint256 => TaskManager.Task) public tasks;
    uint256 public taskCount = 0;

    // Mapping of task IDs to tasks, IDs are numbers starting from 0
    mapping(uint256 => ApplicationManager.Application) public applications;
    uint256 public applicationCount = 0;

    // Minimum stake required to create a Private campaign
    uint256 public minStake = 0.0025 ether;
    // Minimum stake required to create an Open Campaign
    uint256 public minOpenCampaignStake = 0.025 ether;
    // Minimum stake required to enroll in a Project
    uint256 public enrolStake = 0.0025 ether;

    // Minimum time to settle a project
    uint256 public minimumSettledTime = 1 days;
    // Minimum time to gate a project
    uint256 public minimumGateTime = 2.5 days;
    // Within gate, maximum time to decide on submissions
    uint256 public taskSubmissionDecisionTime = 1 days;
    // Within stage, maximum time to dispute a submission decision (encompasses taskSubmissionDecisionTime)
    uint256 public taskSubmissionDecisionDisputeTime = 2 days;

    /// ⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️
    /// MODIFIERS
    // Timestamps
    function checkCampaignExists(uint256 _id) public view {
        require(_id < campaignCount, "E1");
    }

    function checkProjectExists(uint256 _id) public view {
        require(_id < projectCount, "E1");
    }

    function checkTaskExists(uint256 _id) public view {
        require(_id < taskCount, "E1");
    }

    function checkApplicationExists(uint256 _id) public view {
        require(_id < applicationCount, "E1");
    }

    // Campaign Roles
    modifier isCampaignCreator(uint256 _id) {
        require(msg.sender == campaigns[_id].creator, "E2");
        _;
    }
    modifier isCampaignOwner(uint256 _id) {
        require(checkIsCampaignOwner(_id), "E3");
        _;
    }
    modifier isCampaignFunder(uint256 _id) {
        bool isFunder = false;
        for (uint256 i = 0; i < campaigns[_id].fundings.length; i++) {
            if (msg.sender == campaigns[_id].fundings[i].funder) {
                isFunder = true;
                break;
            }
        }
        require(isFunder, "E5");
        _;
    }
    modifier isCampaignAcceptor(uint256 _id) {
        require(checkIsCampaignAcceptor(_id), "E4");
        _;
    }
    modifier isCampaignWorker(uint256 _id) {
        bool isWorker = false;
        for (uint256 i = 0; i < campaigns[_id].workers.length; i++) {
            if (msg.sender == campaigns[_id].workers[i]) {
                isWorker = true;
                break;
            }
        }
        require(isWorker, "E6");
        _;
    }
    modifier isCampaignStakeholder(uint256 _id) {
        bool isStakeholder = false;
        for (
            uint256 i = 0;
            i < campaigns[_id].allTimeStakeholders.length;
            i++
        ) {
            if (msg.sender == campaigns[_id].allTimeStakeholders[i]) {
                isStakeholder = true;
                break;
            }
        }
        require(isStakeholder, "E7");
        _;
    }

    // Campaign Statuses
    modifier isCampaignRunning(uint256 _id) {
        require(
            campaigns[_id].status == CampaignManager.CampaignStatus.Running,
            "E8"
        );
        _;
    }

    // Campaign Money
    modifier isEffectiveBalanceMoreThanZero(uint256 _id) {
        require(getEffectiveCampaignBalance(_id) > 0, "E9");
        _;
    }
    modifier isLockedBalanceMoreThanZero(uint256 _id) {
        require(getCampaignLockedRewards(_id) > 0, "E10");
        _;
    }

    // Project Statuses
    modifier isProjectGate(uint256 _id) {
        require(
            projects[_id].status == ProjectManager.ProjectStatus.Gate,
            "E11"
        );
        _;
    }
    modifier isProjectStage(uint256 _id) {
        require(
            projects[_id].status == ProjectManager.ProjectStatus.Stage,
            "E12"
        );
        _;
    }
    modifier isProjectRunning(uint256 _id) {
        require(
            projects[_id].status != ProjectManager.ProjectStatus.Closed,
            "E13"
        );
        _;
    }

    // Task Statuses
    modifier isTaskNotClosed(uint256 _id) {
        require(!tasks[_id].closed, "E14");
        _;
    }

    // Task Roles
    modifier isWorkerOnTask(uint256 _id) {
        require(msg.sender == tasks[_id].worker, "E15");
        _;
    }

    // Stake & Funding
    modifier isMoneyIntended(uint256 _money) {
        require(msg.value == _money && _money > 0, "E16");
        _;
    }
    modifier isStakeAndFundingIntended(uint256 _stake, uint256 _funding) {
        require(msg.value == _stake + _funding, "E17");
        _;
    }
    modifier isMoreThanEnrolStake(uint256 _stake) {
        require(_stake >= enrolStake, "E18");
        _;
    }

    /// ⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️
    /// CAMPAIGN WRITE FUNCTIONS 🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻
    // Create a new campaign, optionally fund it ✅
    function makeCampaign(
        string memory _metadata,
        // CampaignManager.CampaignStyle _style,
        address payable[] memory _owners,
        address payable[] memory _acceptors,
        uint256 _stake,
        uint256 _funding
    )
        public
        payable
        isStakeAndFundingIntended(_stake, _funding)
        returns (uint256 id)
    {
        if (_stake >= minStake) {
            CampaignManager.Campaign storage campaign = campaigns[
                campaignCount
            ];
            campaign.makeCampaign(
                _metadata,
                // _style,
                _owners,
                _acceptors,
                _stake,
                _funding
            );

            campaignCount++;
            return campaignCount - 1;
        }
    }

    // Update Campaign ⚠️
    function updateCampaign(
        uint256 _id,
        string memory _metadata,
        // CampaignStyle _style,
        //uint256 _deadline,
        CampaignManager.CampaignStatus _status,
        address payable[] memory _owners,
        address payable[] memory _acceptors
    ) public isCampaignOwner(_id) {
        require(_owners.length > 0, "E19");

        CampaignManager.Campaign storage campaign = campaigns[_id];

        if (_status == CampaignManager.CampaignStatus.Closed) {
            // require that all projects inside are closed
            for (uint256 i = 0; i < campaign.allChildProjects.length; i++) {
                require(
                    projects[campaign.allChildProjects[i]].status ==
                        ProjectManager.ProjectStatus.Closed,
                    "E20"
                );
            }
        }

        campaign.updateCampaign(
            _metadata,
            // _style,
            //_deadline,
            _status,
            _owners,
            _acceptors
        );
    }

    // Donate to a campaign ✅
    function fundCampaign(
        uint256 _id,
        uint256 _funding
    ) public payable isMoneyIntended(_funding) {
        checkCampaignExists(_id);
        CampaignManager.Campaign storage campaign = campaigns[_id];
        campaign.fundCampaign(_funding);
    }

    // Refund all campaign fundings ✅
    function refundAllCampaignFundings(
        uint256 _id
    ) public isCampaignOwner(_id) {
        checkCampaignExists(_id);
        CampaignManager.Campaign storage campaign = campaigns[_id];
        campaign.refundAllCampaignFundings();
    }

    // Refund own funding ✅
    function refundOwnFunding(
        uint256 _id,
        uint256 _fundingID
    ) public isCampaignFunder(_id) {
        checkCampaignExists(_id);
        CampaignManager.Campaign storage campaign = campaigns[_id];
        campaign.refundOwnFunding(_fundingID);
    }

    // Refund closed campaign stake ✅
    function refundStake(uint256 _id) public isCampaignCreator(_id) {
        checkCampaignExists(_id);
        CampaignManager.Campaign storage campaign = campaigns[_id];
        campaign.refundStake();
    }

    // Lock amounts of funds by going through each funding and locking until the expense is covered ✅
    function fundLockAmount(
        uint256 _id,
        uint256 _expense
    ) internal isEffectiveBalanceMoreThanZero(_id) {
        checkCampaignExists(_id);
        CampaignManager.Campaign storage campaign = campaigns[_id];
        campaign.fundings.fundLockAmount(_expense);
    }

    // Unlock amounts of funds by going through each funding and unlocking until the expense is covered ✅
    function fundUnlockAmount(
        uint256 _id,
        uint256 _expense
    ) internal isLockedBalanceMoreThanZero(_id) {
        checkCampaignExists(_id);
        CampaignManager.Campaign storage campaign = campaigns[_id];
        campaign.fundings.fundUnlockAmount(_expense);
    }

    // Use amounts of funds by going through each funding and using until the expense is covered ✅
    function fundUseAmount(
        uint256 _id,
        uint256 _expense
    ) internal isLockedBalanceMoreThanZero(_id) {
        checkCampaignExists(_id);
        CampaignManager.Campaign storage campaign = campaigns[_id];
        campaign.fundings.fundUseAmount(_expense);
    }

    // Cleanup all tasks that are not closed at the right time for all projects ✅
    function cleanUpNotClosedTasksForAllProjects(uint256 _id) internal {
        CampaignManager.Campaign storage campaign = campaigns[_id];
        for (uint256 i = 0; i < campaign.allChildProjects.length; i++) {
            cleanUpNotClosedTasks(campaign.allChildProjects[i]);
        }
    }

    // Unlock the funds for all projects that can have their funds unlocked ✅
    function unlockTheFundsForAllProjectsPostCleanup(uint256 _id) internal {
        CampaignManager.Campaign storage campaign = campaigns[_id];
        for (uint256 i = 0; i < campaign.allChildProjects.length; i++) {
            unlockTheFundsForProjectPostCleanup(campaign.allChildProjects[i]);
        }
    }

    /// 🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳
    /// CAMPAIGN READ FUNCTIONS 🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹

    // Get campaign by ID ✅
    function getCampaignByID(
        uint256 _id
    ) public view returns (CampaignManager.Campaign memory) {
        CampaignManager.Campaign memory campaign = campaigns[_id];
        return campaign;
    }

    // Get campaign Fundings struct array ✅
    function getFundingsOfCampaign(
        uint256 _id
    ) public view returns (FundingsManager.Fundings[] memory) {
        return campaigns[_id].fundings;
    }

    // Get the total funding of a campaign ✅
    function getCampaignTotalFunding(
        uint256 _id
    ) public view returns (uint256) {
        checkCampaignExists(_id);
        CampaignManager.Campaign memory campaign = campaigns[_id];
        return campaign.getTotalFunding();
    }

    // Get the total unused balance of a campaign ✅
    function getCampaignUnusedBalance(
        uint256 _id
    ) public view returns (uint256) {
        checkCampaignExists(_id);
        CampaignManager.Campaign memory campaign = campaigns[_id];
        return campaign.getUnusedBalance();
    }

    // Get the total locked rewards of a campaign ✅
    function getCampaignLockedRewards(
        uint256 _id
    ) public view returns (uint256) {
        checkCampaignExists(_id);
        CampaignManager.Campaign memory campaign = campaigns[_id];
        return campaign.getLockedRewards();
    }

    // Get the total EFFECTIVE balance (unused - locked) of a campaign ✅
    function getEffectiveCampaignBalance(
        uint256 _id
    ) public view returns (uint256) {
        checkCampaignExists(_id);
        CampaignManager.Campaign memory campaign = campaigns[_id];
        return CampaignManager.getEffectiveBalance(campaign);
    }

    /// ⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️
    /// PROJECT WRITE FUNCTIONS 🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻
    // Create a new project ✅
    function makeProject(
        string memory _metadata,
        // uint256 _deadline,
        bool _applicationRequired,
        uint256 _parentCampaign,
        uint256 _parentProject
    ) public returns (uint256) {
        checkCampaignExists(_parentCampaign);
        require(_parentProject <= projectCount + 1, "E21");
        ProjectManager.Project storage project = projects[projectCount];
        CampaignManager.Campaign storage parentCampaign = campaigns[
            _parentCampaign
        ];

        // Populate project
        project.metadata = _metadata;
        project.creationTime = block.timestamp;
        project.status = ProjectManager.ProjectStatus.Gate;
        project.nextMilestone = ProjectManager.NextMilestone(0, 0, 0);
        project.applicationRequired = _applicationRequired;

        // // Open campaigns don't require applications
        // if (parentCampaign.style == CampaignManager.CampaignStyle.Open) {
        //     project.applicationRequired = false;
        // } else {
        //     project.applicationRequired = _applicationRequired;
        // }

        // In THIS project being created, set the parent campaign and project
        project.parentCampaign = _parentCampaign;
        project.parentProject = _parentProject; // !!! references itself if at the top level

        // In the PARENTS of THIS project being created, add THIS project to the child projects
        if (_parentProject < projectCount) {
            // If this is not the top level project, add it to the parent project
            projects[_parentProject].childProjects.push(projectCount);
        } else {
            // If this is a top level project, add it in the parent campaign
            parentCampaign.directChildProjects.push(projectCount);
        }

        // Reference project in campaign
        campaigns[_parentCampaign].allChildProjects.push(projectCount);

        projectCount++;
        return projectCount - 1;
    }

    // Close project ✅
    function closeProject(
        uint256 _id
    )
        public
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        isCampaignOwner(projects[_id].parentCampaign)
    {
        checkProjectExists(_id);

        ProjectManager.Project storage project = projects[_id];
        require(project.status == ProjectManager.ProjectStatus.Gate, "E22");
        require(checkIsCampaignOwner(project.parentCampaign), "E23");

        // Just to clear any loose ends
        goToSettledStatus(_id, 0, 1, 2);

        project.status = ProjectManager.ProjectStatus.Closed;

        // Clear fast forward votes
        delete project.fastForward;
    }

    // Go to settled ✅
    function goToSettledStatus(
        uint _id,
        uint256 _nextStageStartTimestamp,
        uint256 _nextGateStartTimestamp,
        uint256 _nextSettledStartTimestamp
    )
        public
        isCampaignRunning(projects[_id].parentCampaign)
        isProjectRunning(_id)
        isProjectGate(_id)
    {
        checkProjectExists(_id);
        // iscampaign running
        statusFixer(_id);
        // isproject running
        //isgate

        ProjectManager.Project storage project = projects[_id];

        // Check conditions for going to settled
        require(toSettledConditions(_id), "E24");
        // Ensure sender is an owner of the campaign
        require(checkIsCampaignOwner(project.parentCampaign), "E25");

        // Ensure timestamps are in order
        require(
            _nextSettledStartTimestamp > _nextGateStartTimestamp &&
                _nextGateStartTimestamp > _nextStageStartTimestamp,
            "E26"
        );

        // Get NotClosed tasks
        uint256[] memory notClosedTaskIds = getTaskIdsOfProjectClosedFilter(
            _id,
            TaskManager.TaskStatusFilter.NotClosed
        );

        // Get latest task deadline
        uint256 latestTaskDeadline = 0;
        for (uint256 i = 0; i < notClosedTaskIds.length; i++) {
            if (tasks[notClosedTaskIds[i]].deadline > latestTaskDeadline) {
                latestTaskDeadline = tasks[notClosedTaskIds[i]].deadline;
            }
        }

        // Update project milestones
        typicalProjectMilestonesUpdate(
            _id,
            _nextStageStartTimestamp,
            _nextGateStartTimestamp,
            _nextSettledStartTimestamp,
            latestTaskDeadline
        );

        // If task deadline is before timestamp of stage start and uncompleted
        // then update deadline of task to be max of stage start and latest task deadline
        // At this point, all deadlines should be between stage start and gate start
        for (uint256 i = 0; i < notClosedTaskIds.length; i++) {
            // Clear workers of unclosed tasks when going settled
            tasks[notClosedTaskIds[i]].worker = payable(address(0));
            // If task deadline is before timestamp of stage start and uncompleted
            if (
                tasks[notClosedTaskIds[i]].deadline <
                project.nextMilestone.startStageTimestamp
            ) {
                tasks[notClosedTaskIds[i]].deadline = Utilities.max(
                    latestTaskDeadline,
                    project.nextMilestone.startGateTimestamp - 1 seconds
                );
            }
        }

        // Lock funds for the project
        fundLockAmount(project.parentCampaign, project.reward);

        // Update project status
        project.status = ProjectManager.ProjectStatus.Settled;

        // Clear fast forward votes
        delete project.fastForward;
    }

    // Update project STATUS ✅
    function updateProjectStatus(
        uint256 _id
    )
        internal
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
    {
        checkProjectExists(_id);
        ProjectManager.Project storage project = projects[_id];

        // GOING INTO STAGE 🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹
        if (project.status == ProjectManager.ProjectStatus.Settled) {
            if (toStageFastForwardConditions(_id)) {
                // update project status
                project.status = ProjectManager.ProjectStatus.Stage;
                // delete all votes
                delete project.fastForward;

                // LOCK FUNDS HERE ⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️
                return;
            } else if (toStageConditions(_id)) {
                // adjust lateness
                adjustLatenessBeforeStage(_id);
                // update project status
                project.status = ProjectManager.ProjectStatus.Stage;
                // delete all votes
                delete project.fastForward;

                // LOCK FUNDS HERE ⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️
                return;
            }
        }
        // GOING INTO GATE 🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹
        else if (project.status == ProjectManager.ProjectStatus.Stage) {
            if (toGateFastForwardConditions(_id)) {
                // update project status
                project.status = ProjectManager.ProjectStatus.Gate;
                // delete all votes
                delete project.fastForward;
                return;
            } else if (toGateConditions(_id)) {
                // update project status
                project.status = ProjectManager.ProjectStatus.Gate;
                // delete all votes
                delete project.fastForward;
                return;
            }
        }
    }

    // Figure out where we are and where we should be and fix is needed ✅
    function statusFixer(uint256 _id) public {
        ProjectManager.Project storage project = projects[_id];
        ProjectManager.ProjectStatus shouldBeStatus = whatStatusProjectShouldBeAt(
                _id
            );

        // If we are where we should be and votes allow to fast forward, try to fast forward
        // Otherwise, do nothing
        if (shouldBeStatus == project.status && checkFastForwardStatus(_id)) {
            updateProjectStatus(_id);
            cleanUpNotClosedTasksForAllProjects(project.parentCampaign);
            unlockTheFundsForAllProjectsPostCleanup(project.parentCampaign);
            computeAllRewardsInCampaign(project.parentCampaign);
        }

        // If we should be in settled but are in gate, then return
        // moving to settled needs owner input so we'll just wait here
        if (
            shouldBeStatus == ProjectManager.ProjectStatus.Settled &&
            project.status == ProjectManager.ProjectStatus.Gate
        ) {
            cleanUpNotClosedTasksForAllProjects(project.parentCampaign);
            unlockTheFundsForAllProjectsPostCleanup(project.parentCampaign);
            computeAllRewardsInCampaign(project.parentCampaign);
            return;
        } else {
            // Iterate until we get to where we should be
            while (shouldBeStatus != project.status) {
                updateProjectStatus(_id);
                shouldBeStatus = whatStatusProjectShouldBeAt(_id);
            }
            cleanUpNotClosedTasksForAllProjects(project.parentCampaign);
            unlockTheFundsForAllProjectsPostCleanup(project.parentCampaign);
            computeAllRewardsInCampaign(project.parentCampaign);
        }
    }

    // Adjust lateness of Project before stage ✅
    function adjustLatenessBeforeStage(
        uint256 _id
    )
        internal
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
    {
        checkProjectExists(_id);
        ProjectManager.Project storage project = projects[_id];
        uint256 lateness = 0;

        // If we are late, add lateness to all tasks and nextmilestone
        if (block.timestamp > project.nextMilestone.startStageTimestamp) {
            lateness =
                block.timestamp -
                project.nextMilestone.startStageTimestamp;
        }

        // Get NotClosed task IDs
        uint256[] memory notClosedTaskIds = getTaskIdsOfProjectClosedFilter(
            _id,
            TaskManager.TaskStatusFilter.NotClosed
        );

        // Add lateness to all tasks
        for (uint256 i = 0; i < notClosedTaskIds.length; i++) {
            tasks[notClosedTaskIds[i]].deadline += lateness; // add lateness to deadline
        }

        // add lateness to nextmilestone
        project.nextMilestone.startGateTimestamp += lateness;
        project.nextMilestone.startSettledTimestamp += lateness;
    }

    // Update project milestones ✅
    function typicalProjectMilestonesUpdate(
        uint256 _id,
        uint256 _nextStageStartTimestamp,
        uint256 _nextGateStartTimestamp,
        uint256 _nextSettledStartTimestamp,
        uint256 latestTaskDeadline
    ) private {
        ProjectManager.Project storage project = projects[_id];

        // Upcoming milestones based on input
        ProjectManager.NextMilestone memory _nextMilestone = ProjectManager
            .NextMilestone(
                // timestamp of stage start must be at least 24 hours from now as grace period
                Utilities.max(
                    _nextStageStartTimestamp,
                    block.timestamp + minimumSettledTime
                ),
                // timestamp of gate start is at least after latest task deadline
                Utilities.max(
                    _nextGateStartTimestamp,
                    latestTaskDeadline + 1 seconds
                ),
                // timestamp of settled start must be after latest task deadline + 2 day
                Utilities.max(
                    _nextSettledStartTimestamp,
                    Utilities.max(
                        _nextGateStartTimestamp,
                        latestTaskDeadline + 1 seconds
                    ) + minimumGateTime
                )
            );

        project.nextMilestone = _nextMilestone;
    }

    // If sender is owner, acceptor or worker, append vote to fast forward status ✅
    function voteFastForwardStatus(uint256 _id, bool _vote) public {
        statusFixer(_id);
        require(
            checkIsCampaignAcceptor(projects[_id].parentCampaign) ||
                checkIsCampaignOwner(projects[_id].parentCampaign) ||
                checkIsProjectWorker(_id),
            "E27"
        );
        ProjectManager.Project storage project = projects[_id];

        bool voterFound = false;

        for (uint256 i = 0; i < project.fastForward.length; i++) {
            if (project.fastForward[i].voter == msg.sender) {
                project.fastForward[i].vote = _vote;
                voterFound = true;
                break;
            }
        }

        if (!voterFound) {
            project.fastForward.push(ProjectManager.Vote(msg.sender, _vote));
        }
    }

    // Worker drop out of project ✅
    function workerDropOut(uint256 _id) public {
        checkProjectExists(_id);
        statusFixer(_id);

        ProjectManager.Project storage project = projects[_id];
        CampaignManager.Campaign storage campaign = campaigns[
            project.parentCampaign
        ];

        // Ensure project status is not stage
        require(
            project.status != ProjectManager.ProjectStatus.Stage &&
                checkIsProjectWorker(_id),
            "E28"
        );

        // Remove worker from project
        Utilities.deleteItemInAddressArray(msg.sender, project.workers);
        // Remove worker from campaign
        Utilities.deleteItemInPayableAddressArray(
            payable(msg.sender),
            campaign.workers
        );

        // Add Worker to pastWorkers in project
        project.pastWorkers.push(msg.sender);

        // Refund stake
        refundWorkerEnrolStake(_id, msg.sender);
    }

    // Remove worker from project by owner ✅
    function fireWorker(
        uint256 _id,
        address _worker
    ) public isCampaignOwner(projects[_id].parentCampaign) {
        checkProjectExists(_id);
        // isOwner?
        statusFixer(_id);
        ProjectManager.Project storage project = projects[_id];
        CampaignManager.Campaign storage campaign = campaigns[
            project.parentCampaign
        ];

        // Ensure worker is on project
        require(checkIsProjectWorker(_id, _worker), "E29");

        // Ensure project status is not stage
        require(project.status != ProjectManager.ProjectStatus.Stage, "E30");

        // Remove worker from project
        Utilities.deleteItemInAddressArray(_worker, project.workers);
        // Remove worker from campaign
        Utilities.deleteItemInPayableAddressArray(
            payable(_worker),
            campaign.workers
        );

        // Add Worker to pastWorkers in project
        project.pastWorkers.push(_worker);

        // Refund stake
        refundWorkerEnrolStake(_id, _worker);
    }

    // Internal function to refund worker enrol stake and delete appliction ✅
    function refundWorkerEnrolStake(
        uint256 _id,
        address _worker
    ) internal isCampaignOwner(projects[_id].parentCampaign) {
        checkProjectExists(_id);
        ProjectManager.Project storage project = projects[_id];

        // Ensure worker is on project
        require(checkIsProjectWorker(_id, _worker), "E31");

        // Ensure project status is not stage
        require(project.status != ProjectManager.ProjectStatus.Stage, "E32");

        // Refund stake
        for (uint256 i = 0; i < project.applications.length; i++) {
            ApplicationManager.Application storage application = applications[
                project.applications[i]
            ];
            // Find worker's application, ensure it was accepted and not refunded
            if (
                application.applicant == _worker &&
                !application.enrolStake.fullyRefunded &&
                application.accepted
            ) {
                // Refund stake in application
                application.enrolStake.amountUsed = application
                    .enrolStake
                    .funding;
                application.enrolStake.fullyRefunded = true;
                payable(_worker).transfer(application.enrolStake.funding);
                Utilities.deleteItemInUintArray(i, project.applications); //-> Get rid of refunded application
            }
        }
    }

    // Enrol to project as worker when no application is required ✅
    function workerEnrolNoApplication(
        uint256 _id,
        uint256 _stake
    )
        public
        payable
        isCampaignRunning(projects[_id].parentCampaign)
        isProjectRunning(_id)
        isMoneyIntended(_stake)
        isMoreThanEnrolStake(_stake)
    {
        checkProjectExists(_id);
        // iscampaignrunning
        statusFixer(_id);
        // isprojectrunning
        // ismoneyintended
        // ismorethanenrolstake

        ProjectManager.Project storage project = projects[_id];
        CampaignManager.Campaign storage campaign = campaigns[
            project.parentCampaign
        ];

        require(!project.applicationRequired, "E33");
        require(!checkIsProjectWorker(_id), "E34");

        // Creates application to deal with stake
        ApplicationManager.Application storage application = applications[
            applicationCount
        ];
        application.metadata = "_";
        application.applicant = msg.sender;
        application.accepted = true;
        application.enrolStake.funder = payable(msg.sender);
        application.enrolStake.funding = _stake;
        application.enrolStake.amountUsed = 0;
        application.enrolStake.fullyRefunded = false;
        application.parentProject = _id;

        project.applications.push(applicationCount);
        applicationCount++;

        project.workers.push(msg.sender);
        campaign.allTimeStakeholders.push(payable(msg.sender));
        campaign.workers.push(payable(msg.sender));
    }

    // Apply to project to become Worker ✅
    function applyToProject(
        uint256 _id,
        string memory _metadata,
        uint256 _stake
    )
        public
        payable
        isCampaignRunning(projects[_id].parentCampaign)
        isProjectRunning(_id)
        isMoneyIntended(_stake)
        isMoreThanEnrolStake(_stake)
        returns (uint256)
    {
        checkCampaignExists(projects[_id].parentCampaign);
        checkProjectExists(_id);
        statusFixer(_id);

        ProjectManager.Project storage project = projects[_id];
        require(project.applicationRequired, "E35");

        require(!checkIsProjectWorker(_id), "E36");

        ApplicationManager.Application storage application = applications[
            applicationCount
        ];
        application.metadata = _metadata;
        application.applicant = msg.sender;
        application.accepted = false;
        application.enrolStake.funder = payable(msg.sender);
        application.enrolStake.funding = _stake;
        application.enrolStake.amountUsed = 0;
        application.enrolStake.fullyRefunded = false;
        application.parentProject = _id;

        project.applications.push(applicationCount);
        applicationCount++;
        return applicationCount - 1;
    }

    // Worker application decision by acceptors ✅
    function applicationDecision(
        uint256 _applicationID,
        bool _accepted
    )
        public
        isCampaignAcceptor(
            projects[applications[_applicationID].parentProject].parentCampaign
        )
    {
        checkProjectExists(applications[_applicationID].parentProject);
        statusFixer(applications[_applicationID].parentProject);
        // campaignacceptor
        checkApplicationExists(_applicationID);

        ApplicationManager.Application storage application = applications[
            _applicationID
        ];
        ProjectManager.Project storage project = projects[
            application.parentProject
        ];
        CampaignManager.Campaign storage campaign = campaigns[
            project.parentCampaign
        ];
        // if project or campaign is closed, decline or if project is past its deadline, decline
        // also refund stake
        if (
            project.status == ProjectManager.ProjectStatus.Closed ||
            campaigns[project.parentCampaign].status ==
            CampaignManager.CampaignStatus.Closed ||
            !_accepted
        ) {
            applications[_applicationID].accepted = false;
            applications[_applicationID].enrolStake.amountUsed = application
                .enrolStake
                .funding;
            applications[_applicationID].enrolStake.fullyRefunded = true;
            Utilities.deleteItemInUintArray(
                _applicationID,
                project.applications
            );
            payable(msg.sender).transfer(
                applications[_applicationID].enrolStake.funding
            );
            return;
        } else if (_accepted) {
            project.workers.push(application.applicant);
            campaign.allTimeStakeholders.push(payable(application.applicant));
            campaign.workers.push(payable(application.applicant));
            application.accepted = true;
            // deleteItemInUintArray(_applicationID, project.applications); maybe?? -> only on refund
        }
    }

    // Compute rewards for all projects and tasks in a campaign ✅
    function computeAllRewardsInCampaign(
        uint256 _id
    ) public isCampaignRunning(_id) {
        checkCampaignExists(projects[_id].parentCampaign);
        // Get the campaign
        CampaignManager.Campaign storage campaign = campaigns[_id];

        // unlock the funds of the project -> inside check we're past decision time and dispute time

        // Effective campaign balance that rewards can draw from at that time
        uint256 effectiveCampaignBalance = getEffectiveCampaignBalance(_id);

        // Loop over all direct projects in the campaign
        for (uint256 i = 0; i < campaign.directChildProjects.length; i++) {
            uint256 projectId = campaign.directChildProjects[i];

            // Compute rewards for the project and its tasks recursively
            computeProjectRewards(projectId, effectiveCampaignBalance);
        }
    }

    // Compute rewards for all projects and tasks in a campaign helper function ✅
    function computeProjectRewards(
        uint256 _id,
        uint256 _fundsAtThatLevel
    ) internal {
        checkProjectExists(_id);
        ProjectManager.Project storage project = projects[_id];
        uint256 thisProjectReward;

        if (project.status == ProjectManager.ProjectStatus.Closed) {
            return;
        }

        // If the project is top level project
        if (project.parentProject == _id) {
            // Compute the reward for the project at this level
            thisProjectReward = (_fundsAtThatLevel * project.weight) / 1000;
            // If the project fulfills conditions, then actually update the reward
            if (updateProjectRewardsConditions(_id)) {
                project.reward = thisProjectReward;
            }
        } else {
            // If the project is not a top level project take the reward
            // given from the parent project computation
            if (updateProjectRewardsConditions(_id)) {
                project.reward = _fundsAtThatLevel;
            }
        }

        uint256[] memory notClosedTaskIds = getTaskIdsOfProjectClosedFilter(
            _id,
            TaskManager.TaskStatusFilter.NotClosed
        );

        // Updating tasks requires reward conditions to be met
        if (updateProjectRewardsConditions(_id)) {
            // Compute the reward for each task at this level)
            for (uint256 i = 0; i < notClosedTaskIds.length; i++) {
                // Compute the reward based on the task's weight and the total weight
                uint256 taskReward = (thisProjectReward *
                    tasks[notClosedTaskIds[i]].weight) / 1000;

                // Update the task reward in storage
                tasks[notClosedTaskIds[i]].reward = taskReward;
            }
        }

        // Compute the rewards for child projects
        for (uint256 i = 0; i < project.childProjects.length; i++) {
            uint256 childProjectId = project.childProjects[i];
            ProjectManager.Project storage childProject = projects[
                childProjectId
            ];

            // If project is NOT closed, then compute rewards
            if (childProject.status != ProjectManager.ProjectStatus.Closed) {
                // Calculate rewards for the child project
                uint256 childProjectReward = (thisProjectReward *
                    childProject.weight) / 1000;
                // Compute rewards for the child project and its tasks recursively
                computeProjectRewards(childProjectId, childProjectReward);
            }
        }
    }

    // Check if project can update the rewards ✅
    function updateProjectRewardsConditions(
        uint256 _id
    ) public view returns (bool) {
        ProjectManager.Project storage project = projects[_id];

        bool atGate = project.status == ProjectManager.ProjectStatus.Gate ||
            project.status == ProjectManager.ProjectStatus.Closed;
        bool afterCleanup = block.timestamp >
            project.nextMilestone.startGateTimestamp +
                taskSubmissionDecisionDisputeTime;

        // Ensure all conditions are met
        return atGate && afterCleanup;
    }

    /// 🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳
    /// PROJECT READ FUNCTIONS 🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹

    // Returns the status corresponding to our current timestamp ✅
    function whatStatusProjectShouldBeAt(
        uint256 _id
    )
        public
        view
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        returns (ProjectManager.ProjectStatus)
    {
        checkProjectExists(_id);
        ProjectManager.Project storage project = projects[_id];
        require(project.status != ProjectManager.ProjectStatus.Closed, "E37");
        if (block.timestamp < project.nextMilestone.startStageTimestamp) {
            return ProjectManager.ProjectStatus.Settled;
        } else if (block.timestamp < project.nextMilestone.startGateTimestamp) {
            return ProjectManager.ProjectStatus.Stage;
        } else if (
            block.timestamp < project.nextMilestone.startSettledTimestamp
        ) {
            return ProjectManager.ProjectStatus.Gate;
        } else {
            return ProjectManager.ProjectStatus.Settled;
        }
    }

    // Conditions for going to Stage ✅
    function toStageConditions(
        uint256 _id
    )
        public
        view
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        returns (bool)
    {
        checkProjectExists(_id);
        ProjectManager.Project storage project = projects[_id];
        TaskManager.Task[]
            memory notClosedTasks = getTasksOfProjectClosedFilter(
                _id,
                TaskManager.TaskStatusFilter.NotClosed
            );

        bool currentStatusValid = project.status ==
            ProjectManager.ProjectStatus.Settled;
        bool projectHasWorkers = project.workers.length > 0;
        bool allTasksHaveWorkers = true;
        bool inStagePeriod = block.timestamp >=
            project.nextMilestone.startStageTimestamp;

        // Ensure all tasks have workers
        for (uint256 i = 0; i < notClosedTasks.length; i++) {
            if (notClosedTasks[i].worker == address(0)) {
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

    // Conditions for fast forwarding to Stage ✅
    function toStageFastForwardConditions(
        uint256 _id
    )
        public
        view
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        returns (bool)
    {
        checkProjectExists(_id);
        ProjectManager.Project storage project = projects[_id];
        TaskManager.Task[]
            memory notClosedTasks = getTasksOfProjectClosedFilter(
                _id,
                TaskManager.TaskStatusFilter.NotClosed
            );

        bool currentStatusValid = project.status ==
            ProjectManager.ProjectStatus.Settled;
        bool projectHasWorkers = project.workers.length > 0;
        bool allTasksHaveWorkers = true;
        bool stillInSettledPeriod = block.timestamp <
            project.nextMilestone.startStageTimestamp;

        // Ensure all tasks have workers
        for (uint256 i = 0; i < notClosedTasks.length; i++) {
            if (notClosedTasks[i].worker == address(0)) {
                allTasksHaveWorkers = false;
                return false;
            }
        }

        // All conditions must be true to go to stage
        return
            allTasksHaveWorkers &&
            currentStatusValid &&
            projectHasWorkers &&
            stillInSettledPeriod &&
            checkFastForwardStatus(_id);
    }

    // Conditions for going to Gate ✅
    function toGateConditions(
        uint256 _id
    )
        public
        view
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        returns (bool)
    {
        checkProjectExists(_id);
        ProjectManager.Project storage project = projects[_id];
        bool currentStatusValid = project.status ==
            ProjectManager.ProjectStatus.Stage;
        bool inGatePeriod = block.timestamp >=
            project.nextMilestone.startGateTimestamp;

        return currentStatusValid && inGatePeriod;
    }

    // Conditions for fast forwarding to Gate ✅
    function toGateFastForwardConditions(
        uint256 _id
    )
        public
        view
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        returns (bool)
    {
        checkProjectExists(_id);
        ProjectManager.Project storage project = projects[_id];
        bool currentStatusValid = project.status ==
            ProjectManager.ProjectStatus.Stage;
        bool stillInStagePeriod = block.timestamp <
            project.nextMilestone.startGateTimestamp;
        bool allTasksHaveSubmissions = true;

        // Ensure all NotClosed tasks have submissions
        TaskManager.Task[]
            memory notClosedTasks = getTasksOfProjectClosedFilter(
                _id,
                TaskManager.TaskStatusFilter.NotClosed
            );
        for (uint256 i = 0; i < notClosedTasks.length; i++) {
            if (
                notClosedTasks[i].submission.status ==
                TaskManager.SubmissionStatus.None
            ) {
                allTasksHaveSubmissions = false;
                return false;
            }
        }

        return
            currentStatusValid &&
            stillInStagePeriod &&
            allTasksHaveSubmissions &&
            checkFastForwardStatus(_id);
    }

    // Conditions for going to Settled ✅
    function toSettledConditions(
        uint256 _id
    )
        public
        view
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        returns (bool)
    {
        checkProjectExists(_id);
        ProjectManager.Project storage project = projects[_id];

        bool currentStatusValid = project.status ==
            ProjectManager.ProjectStatus.Gate;
        bool inSettledPeriod = block.timestamp >=
            project.nextMilestone.startSettledTimestamp;

        return currentStatusValid && inSettledPeriod;
    }

    // Checks that voting conditions are met ✅
    function checkFastForwardStatus(uint256 _id) public view returns (bool) {
        ProjectManager.Project storage project = projects[_id];

        // Check for each vote in the fastForward array, if at least 1 owner
        // and all workers voted true, and conditions are fulfilled,
        // then move to next stage/gate/settled
        uint256 ownerVotes = 0;
        uint256 workerVotes = 0;
        uint256 acceptorVotes = 0;

        for (uint256 i = 0; i < project.fastForward.length; i++) {
            if (
                checkIsProjectWorker(_id, project.fastForward[i].voter) &&
                project.fastForward[i].vote
            ) {
                workerVotes++;
            } else {
                return false;
            }
            if (
                checkIsCampaignOwner(_id, project.fastForward[i].voter) &&
                project.fastForward[i].vote
            ) {
                ownerVotes++;
            }
            if (
                checkIsCampaignAcceptor(_id, project.fastForward[i].voter) &&
                project.fastForward[i].vote
            ) {
                acceptorVotes++;
            }
        }

        return
            ownerVotes > 0 &&
            acceptorVotes > 0 &&
            project.workers.length <= workerVotes;
    }

    // Check if sender is owner of campaign ✅
    function checkIsCampaignOwner(uint256 _id) public view returns (bool) {
        bool isOwner = false;
        for (uint256 i = 0; i < campaigns[_id].owners.length; i++) {
            if (msg.sender == campaigns[_id].owners[i]) {
                isOwner = true;
                break;
            }
        }
        return isOwner;
    }

    // Overloading: Check if address is owner of campaign ✅
    function checkIsCampaignOwner(
        uint256 _id,
        address _address
    ) public view returns (bool) {
        bool isOwner = false;
        for (uint256 i = 0; i < campaigns[_id].owners.length; i++) {
            if (_address == campaigns[_id].owners[i]) {
                isOwner = true;
                break;
            }
        }
        return isOwner;
    }

    // Check if sender is acceptor of campaign ✅
    function checkIsCampaignAcceptor(uint256 _id) public view returns (bool) {
        bool isAcceptor = false;
        for (uint256 i = 0; i < campaigns[_id].acceptors.length; i++) {
            if (msg.sender == campaigns[_id].acceptors[i]) {
                isAcceptor = true;
                break;
            }
        }
        return isAcceptor;
    }

    // Overloading: Check if address is acceptor of campaign ✅
    function checkIsCampaignAcceptor(
        uint256 _id,
        address _address
    ) public view returns (bool) {
        bool isAcceptor = false;
        for (uint256 i = 0; i < campaigns[_id].acceptors.length; i++) {
            if (_address == campaigns[_id].acceptors[i]) {
                isAcceptor = true;
                break;
            }
        }
        return isAcceptor;
    }

    // Check if sender is worker of project ✅
    function checkIsProjectWorker(uint256 _id) public view returns (bool) {
        bool isWorker = false;
        for (uint256 i = 0; i < projects[_id].workers.length; i++) {
            if (msg.sender == projects[_id].workers[i]) {
                isWorker = true;
                break;
            }
        }
        return isWorker;
    }

    // Overloading: Check if address is worker of project ✅
    function checkIsProjectWorker(
        uint256 _id,
        address _address
    ) public view returns (bool) {
        bool isWorker = false;
        for (uint256 i = 0; i < projects[_id].workers.length; i++) {
            if (_address == projects[_id].workers[i]) {
                isWorker = true;
                break;
            }
        }
        return isWorker;
    }

    // Get the application of a worker on a project by their address ✅
    function getApplicationByApplicant(
        uint256 _id,
        address _applicant
    ) public view returns (ApplicationManager.Application memory application) {
        ProjectManager.Project storage project = projects[_id];
        for (uint256 i = 0; i < project.applications.length; i++) {
            if (applications[project.applications[i]].applicant == _applicant) {
                return applications[project.applications[i]];
            }
        }
    }

    /// ⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️
    /// TASK WRITE FUNCTIONS 🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻
    // Create a new task
    function makeTask(
        string memory _metadata,
        uint256 weight,
        uint256 _deadline,
        uint256 _parentProjectID
    )
        public
        isCampaignOwner(projects[_parentProjectID].parentCampaign)
        returns (uint256)
    {
        checkProjectExists(_parentProjectID);
        checkCampaignExists(projects[_parentProjectID].parentCampaign);
        require(_deadline > block.timestamp, "E38");

        TaskManager.Task storage task = tasks[taskCount];

        task.metadata = _metadata;
        task.weight = weight;
        task.creationTime = block.timestamp;
        task.deadline = _deadline;
        task.closed = false;

        // Add parent project to task and vice versa
        task.parentProject = _parentProjectID;
        projects[_parentProjectID].childTasks.push(taskCount);

        taskCount++;

        return taskCount - 1;
    }

    // Submit a submission to a task ✅
    function submitSubmission(
        uint256 _id,
        string memory _metadata
    )
        public
        isProjectRunning(tasks[_id].parentProject)
        isWorkerOnTask(_id)
        isTaskNotClosed(_id)
        isProjectStage(tasks[_id].parentProject)
    {
        checkTaskExists(_id);
        checkProjectExists(tasks[_id].parentProject);
        statusFixer(tasks[_id].parentProject);

        TaskManager.Task storage task = tasks[_id];
        require(task.deadline > block.timestamp, "E39");

        // Create submission, if it already exists, overwrite it
        TaskManager.Submission storage submission = task.submission;
        // Attach the IPFS hash for metadata
        submission.metadata = _metadata;
        // Submission status is pending after submission
        submission.status = TaskManager.SubmissionStatus.Pending;
    }

    // Submission decision by acceptors ✅
    function submissionDecision(
        uint256 _id,
        bool _accepted
    )
        public
        isProjectRunning(tasks[_id].parentProject)
        isCampaignAcceptor(projects[tasks[_id].parentProject].parentCampaign)
        isTaskNotClosed(_id)
        isProjectGate(tasks[_id].parentProject)
    {
        checkTaskExists(_id);
        checkProjectExists(tasks[_id].parentProject);
        statusFixer(tasks[_id].parentProject);

        ProjectManager.Project storage project = projects[
            tasks[_id].parentProject
        ];
        // Campaign storage campaign = campaigns[project.parentCampaign];
        TaskManager.Task storage task = tasks[_id];
        TaskManager.Submission storage submission = task.submission;

        require(
            block.timestamp <
                project.nextMilestone.startGateTimestamp +
                    taskSubmissionDecisionTime,
            "E40"
        );
        require(
            submission.status == TaskManager.SubmissionStatus.Pending,
            "E41"
        );

        // If decision is accepted, set submission status to accepted,
        // payout worker, update locked rewards and close task
        if (_accepted) {
            submission.status = TaskManager.SubmissionStatus.Accepted;
            task.paid = true;
            task.closed = true;
            task.worker.transfer(task.reward);
            //campaign.lockedRewards -= task.reward;
        } else {
            submission.status = TaskManager.SubmissionStatus.Declined;
        }
    }

    // Automatically accept decisions which have not received a submission and are past the decision time ✅
    // Also automatically close tasks which have received declined submissions
    // and weren't disputed within the dispute time
    function cleanUpNotClosedTasks(uint256 _id) internal {
        ProjectManager.Project storage project = projects[_id];
        // Campaign storage campaign = campaigns[project.parentCampaign];

        // Past the decision time for submissions anyone can trigger the cleanup
        if (
            block.timestamp <=
            project.nextMilestone.startGateTimestamp +
                taskSubmissionDecisionTime
        ) {
            return;
        }

        // Get NotClosed tasks
        uint256[] memory notClosedTaskIds = getTaskIdsOfProjectClosedFilter(
            _id,
            TaskManager.TaskStatusFilter.NotClosed
        );

        for (uint256 i = 0; i < notClosedTaskIds.length; i++) {
            TaskManager.Task storage task = tasks[notClosedTaskIds[i]];
            if (
                task.submission.status == TaskManager.SubmissionStatus.Pending
            ) {
                task.submission.status = TaskManager.SubmissionStatus.Accepted;
                task.closed = true;
                task.paid = true;
                task.worker.transfer(task.reward);
                //campaign.lockedRewards -= task.reward;
            }

            if (
                task.submission.status ==
                TaskManager.SubmissionStatus.Declined &&
                block.timestamp >=
                project.nextMilestone.startGateTimestamp +
                    taskSubmissionDecisionDisputeTime
            ) {
                task.closed = true;
                task.paid = false;
                //campaign.lockedRewards -= task.reward;
            }
        }
    }

    function unlockTheFundsForProjectPostCleanup(uint256 _id) internal {
        ProjectManager.Project storage project = projects[_id];

        // We must be past the decision time and dispute time
        if (
            block.timestamp <=
            project.nextMilestone.startGateTimestamp +
                taskSubmissionDecisionDisputeTime
        ) {
            return;
        }

        // Unlock the funds for the project
        fundUnlockAmount(project.parentCampaign, project.reward);
    }

    // Assign a worker to a task ✅
    function workerSelfAssignsTask(uint256 _id) public isTaskNotClosed(_id) {
        checkTaskExists(_id);
        checkProjectExists(tasks[_id].parentProject);
        statusFixer(tasks[_id].parentProject);

        TaskManager.Task storage task = tasks[_id];
        ProjectManager.Project storage project = projects[task.parentProject];

        require(
            project.status == ProjectManager.ProjectStatus.Settled &&
                checkIsProjectWorker(_id),
            "E42"
        );

        // If stake by sender is strictly superior than stake of current worker on task
        // then remove current worker from task and assign sender to task
        if (task.worker != address(0)) {
            if (
                getApplicationByApplicant(_id, task.worker).enrolStake.funding <
                getApplicationByApplicant(_id, msg.sender).enrolStake.funding
            ) {
                // Remove worker from task
                task.worker = payable(address(0));
                // Assign sender to task
                task.worker = payable(msg.sender);
                return;
            } else {
                return;
            }
        } else {
            // Assign sender to task
            task.worker = payable(msg.sender);
        }
    }

    // Raise a dispute on a declined submission ✅
    // ⚠️ -> needs functionality behind it, currently just a placeholder
    // funds locked in a dispute should be locked in the campaign until
    // the dispute is resolved
    function raiseDeclinedSubmissionDispute(
        uint256 _id,
        string memory _metadata
    )
        public
        isProjectRunning(tasks[_id].parentProject)
        isWorkerOnTask(_id)
        isTaskNotClosed(_id)
        isProjectGate(tasks[_id].parentProject)
    {
        checkTaskExists(_id);
        checkProjectExists(tasks[_id].parentProject);
        statusFixer(tasks[_id].parentProject);

        TaskManager.Task storage task = tasks[_id];
        ProjectManager.Project storage project = projects[task.parentProject];
        TaskManager.Submission storage submission = task.submission;

        require(
            submission.status == TaskManager.SubmissionStatus.Declined,
            "E43"
        );
        require(
            block.timestamp <
                project.nextMilestone.startGateTimestamp +
                    taskSubmissionDecisionDisputeTime,
            "E44"
        );

        submission.status = TaskManager.SubmissionStatus.Disputed;
        task.closed = true;
        task.paid = false;

        dispute(_id, _metadata);
    }

    /// 🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳
    /// TASK READ FUNCTIONS 🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹

    // How many tasks match filter? helper function for getTasksOfProjectClosedFilter() below✅
    function countTasksWithFilter(
        uint256 _id,
        TaskManager.TaskStatusFilter _statusFilter
    ) internal view returns (uint256) {
        uint256 taskCounter = 0;
        uint256[] memory childTasks = projects[_id].childTasks;
        for (uint256 i = 0; i < childTasks.length; i++) {
            if (
                _statusFilter == TaskManager.TaskStatusFilter.Closed &&
                tasks[childTasks[i]].closed
            ) {
                taskCounter++;
            } else if (
                _statusFilter == TaskManager.TaskStatusFilter.NotClosed &&
                !tasks[childTasks[i]].closed
            ) {
                taskCounter++;
            } else if (_statusFilter == TaskManager.TaskStatusFilter.All) {
                taskCounter++;
            }
        }
        return taskCounter;
    }

    // Get tasks in a project based on Closed/NotClosed filter✅
    function getTasksOfProjectClosedFilter(
        uint256 _id,
        TaskManager.TaskStatusFilter _statusFilter
    ) public view returns (TaskManager.Task[] memory) {
        ProjectManager.Project memory parentProject = projects[_id];
        if (_statusFilter == TaskManager.TaskStatusFilter.NotClosed) {
            // Get uncompleted tasks
            TaskManager.Task[] memory _tasks = new TaskManager.Task[](
                countTasksWithFilter(_id, _statusFilter)
            );
            uint256 j = 0;
            for (uint256 i = 0; i < parentProject.childTasks.length; i++) {
                if (!tasks[parentProject.childTasks[i]].closed) {
                    _tasks[j] = tasks[parentProject.childTasks[i]];
                    j++;
                }
            }
            return _tasks;
        } else if (_statusFilter == TaskManager.TaskStatusFilter.Closed) {
            // Get completed tasks
            TaskManager.Task[] memory _tasks = new TaskManager.Task[](
                countTasksWithFilter(_id, _statusFilter)
            );
            uint256 j = 0;
            for (uint256 i = 0; i < parentProject.childTasks.length; i++) {
                if (tasks[parentProject.childTasks[i]].closed) {
                    _tasks[j] = tasks[parentProject.childTasks[i]];
                    j++;
                }
            }
            return _tasks;
        } else {
            // Get all tasks
            TaskManager.Task[] memory _tasks = new TaskManager.Task[](
                parentProject.childTasks.length
            );
            for (uint256 i = 0; i < parentProject.childTasks.length; i++) {
                _tasks[i] = tasks[parentProject.childTasks[i]];
            }
            return _tasks;
        }
    }

    // Get task IDs in a project based on Closed/NotClosed filter✅
    function getTaskIdsOfProjectClosedFilter(
        uint256 _id,
        TaskManager.TaskStatusFilter _statusFilter
    ) public view returns (uint256[] memory) {
        ProjectManager.Project memory parentProject = projects[_id];
        if (_statusFilter == TaskManager.TaskStatusFilter.NotClosed) {
            // Get uncompleted tasks
            uint256[] memory _tasks = new uint256[](
                countTasksWithFilter(_id, _statusFilter)
            );
            uint256 j = 0;
            for (uint256 i = 0; i < parentProject.childTasks.length; i++) {
                if (!tasks[parentProject.childTasks[i]].closed) {
                    _tasks[j] = parentProject.childTasks[i];
                    j++;
                }
            }
            return _tasks;
        } else if (_statusFilter == TaskManager.TaskStatusFilter.Closed) {
            // Get completed tasks
            uint256[] memory _tasks = new uint256[](
                countTasksWithFilter(_id, _statusFilter)
            );
            uint256 j = 0;
            for (uint256 i = 0; i < parentProject.childTasks.length; i++) {
                if (tasks[parentProject.childTasks[i]].closed) {
                    _tasks[j] = parentProject.childTasks[i];
                    j++;
                }
            }
            return _tasks;
        } else {
            // Get all tasks
            uint256[] memory _tasks = new uint256[](
                parentProject.childTasks.length
            );
            for (uint256 i = 0; i < parentProject.childTasks.length; i++) {
                _tasks[i] = parentProject.childTasks[i];
            }
            return _tasks;
        }
    }

    /// ⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️
    /// DEVELOPER FUNCTIONS (ONLY FOR TESTING) 🧑‍💻🧑‍💻🧑‍💻🧑‍💻🧑‍💻
    address public contractMaster;

    constructor() payable {
        contractMaster = payable(msg.sender);
    }

    function contractMasterDrain() public {
        require(msg.sender == contractMaster, "E45");
        payable(msg.sender).transfer(address(this).balance);
    }

    function dispute(
        uint256 _id,
        string memory _metadata
    ) public isCampaignStakeholder(_id) {
        emit Dispute(_id, _metadata);
    }

    event Dispute(uint256 _id, string _metadata);

    receive() external payable {}

    fallback() external payable {}
}
