// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./Utilities.sol";
import "./FundingsManager.sol";

contract StandardCampaign {
    using Utilities for uint256[];
    using Utilities for address[];
    using Utilities for address payable[];
    using FundingsManager for Fundings[];

    struct Project {
        // Description of the project
        string title;
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

    // Mapping of project IDs to projects, IDs are numbers starting from 0
    mapping(uint256 => Project) public projects;
    uint256 public projectCount = 0;

    struct Application {
        // Description of the application
        string metadata;
        address applicant;
        bool accepted;
        Fundings enrolStake;
        // Parent Project (contains IDs)
        uint256 parentProject;
    }

    // Mapping of task IDs to tasks, IDs are numbers starting from 0
    mapping(uint256 => Application) public applications;
    uint256 public applicationCount = 0;

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
    modifier isFutureTimestamp(uint256 timestamp) {
        require(timestamp > block.timestamp, "Timestamp must be in the future");
        _;
    }

    modifier isProjectExisting(uint256 _id) {
        require(_id < projectCount, "Project does not exist");
        _;
    }

    // Campaign Roles
    modifier isCampaignCreator(uint256 _id) {
        require(
            msg.sender == campaigns[_id].creator,
            "Sender must be the campaign creator"
        );
        _;
    }
    modifier isCampaignOwner(uint256 _id) {
        require(
            checkIsCampaignOwner(_id),
            "Sender must be an owner of the campaign"
        );
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
        require(isFunder, "Sender must be a funder of the campaign");
        _;
    }
    modifier isCampaignAcceptor(uint256 _id) {
        require(
            checkIsCampaignAcceptor(_id),
            "Sender must be an acceptor of the campaign"
        );
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
        require(isWorker, "Sender must be a worker of the campaign");
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
        require(isStakeholder, "Sender must be a stakeholder of the campaign");
        _;
    }

    // Campaign Statuses
    modifier isCampaignRunning(uint256 _id) {
        require(
            campaigns[_id].status == CampaignStatus.Running,
            "Campaign must be running"
        );
        _;
    }

    // Campaign Money
    modifier isEffectiveBalanceMoreThanZero(uint256 _id) {
        require(
            getEffectiveCampaignBalance(_id) > 0,
            "Effective balance must be greater than zero"
        );
        _;
    }
    modifier isLockedBalanceMoreThanZero(uint256 _id) {
        require(
            getCampaignLockedRewards(_id) > 0,
            "Locked balance must be greater than zero"
        );
        _;
    }

    // Project Statuses
    modifier isProjectGate(uint256 _id) {
        require(
            projects[_id].status == ProjectStatus.Gate,
            "Project must be at gate"
        );
        _;
    }
    modifier isProjectStage(uint256 _id) {
        require(
            projects[_id].status == ProjectStatus.Stage,
            "Project must be at stage"
        );
        _;
    }
    modifier isProjectRunning(uint256 _id) {
        require(
            projects[_id].status != ProjectStatus.Closed,
            "Project must be running"
        );
        _;
    }

    // Task Statuses
    modifier isTaskNotClosed(uint256 _id) {
        require(!tasks[_id].closed, "Task must not be closed");
        _;
    }

    // Lazy Project Status Updater
    modifier lazyStatusUpdaterStart(uint256 _id) {
        statusFixer(_id);
        _;
    }

    // Task Roles
    modifier isWorkerOnTask(uint256 _id) {
        require(
            msg.sender == tasks[_id].worker,
            "Sender must be the task worker"
        );
        _;
    }

    // Stake & Funding
    modifier isMoneyIntended(uint256 _money) {
        require(
            msg.value == _money && _money > 0,
            "Ether sent must be equal to intended funding"
        );
        _;
    }
    modifier isStakeAndFundingIntended(uint256 _stake, uint256 _funding) {
        require(
            msg.value == _stake + _funding,
            "Ether sent must be equal to intended stake"
        );
        _;
    }
    modifier isMoreThanEnrolStake(uint256 _stake) {
        require(
            _stake >= enrolStake,
            "Intended stake must be greater or equal to enrolStake"
        );
        _;
    }

    // Lock amounts of funds by going through each funding and locking until the expense is covered ✅
    function fundLockAmount(
        uint256 _id,
        uint256 _expense
    ) internal isCampaignExisting(_id) isEffectiveBalanceMoreThanZero(_id) {
        Campaign storage campaign = campaigns[_id];
        // Calls the library function on the campaign's fundings array
        campaign.fundings.fundLockAmount(_expense);
    }

    // Unlock amounts of funds by going through each funding and unlocking until the expense is covered ✅
    function fundUnlockAmount(
        uint256 _id,
        uint256 _expense
    ) internal isCampaignExisting(_id) isLockedBalanceMoreThanZero(_id) {
        Campaign storage campaign = campaigns[_id];

        // If the expense is to be unlocked, remove it from the amountLocked of the fundings (in reverse order)
        campaign.fundings.fundUnlockAmount(_expense);
    }

    // Use amounts of funds by going through each funding and using until the expense is covered ✅
    function fundUseAmount(
        uint256 _id,
        uint256 _expense
    ) internal isCampaignExisting(_id) isLockedBalanceMoreThanZero(_id) {
        Campaign storage campaign = campaigns[_id];

        // If the expense is to be used, add it to the amountUsed of the fundings
        // loop over all the non fullyRefunded fundings and add a part to amountUsed which is proportional to how much the funding is
        campaign.fundings.fundUseAmount(_expense);
    }

    /// ⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️
    /// PROJECT WRITE FUNCTIONS 🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻
    // Create a new project ✅
    function makeProject(
        string memory _title,
        string memory _metadata,
        uint256 _deadline,
        bool _applicationRequired,
        uint256 _parentCampaign,
        uint256 _parentProject
    )
        public
        isFutureTimestamp(_deadline)
        isCampaignExisting(_parentCampaign)
        returns (uint256)
    {
        require(
            _parentProject <= projectCount + 1,
            "Parent project must exist or be the next top-level project to be created"
        );
        Project storage project = projects[projectCount];
        Campaign storage parentCampaign = campaigns[_parentCampaign];

        // Populate project
        project.title = _title;
        project.metadata = _metadata;
        project.creationTime = block.timestamp;
        project.status = ProjectStatus.Gate;
        project.nextMilestone = NextMilestone(0, 0, 0);

        // Open campaigns don't require applications
        if (parentCampaign.style == CampaignStyle.Open) {
            project.applicationRequired = false;
        } else {
            project.applicationRequired = _applicationRequired;
        }

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
        isProjectExisting(_id)
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        isCampaignOwner(projects[_id].parentCampaign)
    {
        Project storage project = projects[_id];
        require(
            project.status == ProjectStatus.Gate,
            "Project must currently be at gate"
        );
        require(
            checkIsCampaignOwner(project.parentCampaign),
            "Sender must be an owner of the campaign"
        );

        // Just to clear any loose ends
        goToSettledStatus(_id, 0, 1, 2);

        project.status = ProjectStatus.Closed;

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
        isProjectExisting(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        lazyStatusUpdaterStart(_id)
        isProjectRunning(_id)
        isProjectGate(_id)
    {
        Project storage project = projects[_id];

        // Check conditions for going to settled
        require(toSettledConditions(_id), "Project cannot go to settled");
        // Ensure sender is an owner of the campaign
        require(
            checkIsCampaignOwner(project.parentCampaign),
            "Sender must be an owner of the campaign"
        );

        // Ensure timestamps are in order
        require(
            _nextSettledStartTimestamp > _nextGateStartTimestamp &&
                _nextGateStartTimestamp > _nextStageStartTimestamp,
            "_nextGateStartTimestamp must be after _nextStageStartTimestamp"
        );

        // Get NotClosed tasks
        uint256[] memory notClosedTaskIds = getTaskIdsOfProjectClosedFilter(
            _id,
            TaskStatusFilter.NotClosed
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
        project.status = ProjectStatus.Settled;

        // Clear fast forward votes
        delete project.fastForward;
    }

    // Update project STATUS ✅
    function updateProjectStatus(
        uint256 _id
    )
        internal
        isProjectExisting(_id)
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
    {
        Project storage project = projects[_id];

        // GOING INTO STAGE 🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹
        if (project.status == ProjectStatus.Settled) {
            if (toStageFastForwardConditions(_id)) {
                // update project status
                project.status = ProjectStatus.Stage;
                // delete all votes
                delete project.fastForward;

                // LOCK FUNDS HERE ⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️
                return;
            } else if (toStageConditions(_id)) {
                // adjust lateness
                adjustLatenessBeforeStage(_id);
                // update project status
                project.status = ProjectStatus.Stage;
                // delete all votes
                delete project.fastForward;

                // LOCK FUNDS HERE ⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️
                return;
            }
        }
        // GOING INTO GATE 🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹
        else if (project.status == ProjectStatus.Stage) {
            if (toGateFastForwardConditions(_id)) {
                // update project status
                project.status = ProjectStatus.Gate;
                // delete all votes
                delete project.fastForward;
                return;
            } else if (toGateConditions(_id)) {
                // update project status
                project.status = ProjectStatus.Gate;
                // delete all votes
                delete project.fastForward;
                return;
            }
        }
    }

    // Figure out where we are and where we should be and fix is needed ✅
    function statusFixer(uint256 _id) public {
        Project storage project = projects[_id];
        ProjectStatus shouldBeStatus = whatStatusProjectShouldBeAt(_id);

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
            shouldBeStatus == ProjectStatus.Settled &&
            project.status == ProjectStatus.Gate
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
        isProjectExisting(_id)
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
    {
        Project storage project = projects[_id];
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
            TaskStatusFilter.NotClosed
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
        Project storage project = projects[_id];

        // Upcoming milestones based on input
        NextMilestone memory _nextMilestone = NextMilestone(
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
    function voteFastForwardStatus(
        uint256 _id,
        bool _vote
    ) public lazyStatusUpdaterStart(_id) {
        require(
            checkIsCampaignAcceptor(projects[_id].parentCampaign) ||
                checkIsCampaignOwner(projects[_id].parentCampaign) ||
                checkIsProjectWorker(_id),
            "Sender must be an acceptor, worker or owner"
        );
        Project storage project = projects[_id];

        bool voterFound = false;

        for (uint256 i = 0; i < project.fastForward.length; i++) {
            if (project.fastForward[i].voter == msg.sender) {
                project.fastForward[i].vote = _vote;
                voterFound = true;
                break;
            }
        }

        if (!voterFound) {
            project.fastForward.push(Vote(msg.sender, _vote));
        }
    }

    // Worker drop out of project ✅
    function workerDropOut(
        uint256 _id
    ) public isProjectExisting(_id) lazyStatusUpdaterStart(_id) {
        Project storage project = projects[_id];
        Campaign storage campaign = campaigns[project.parentCampaign];

        // Ensure project status is not stage
        require(
            project.status != ProjectStatus.Stage && checkIsProjectWorker(_id),
            "Project must currently be at gate or settled or closed"
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
    )
        public
        isProjectExisting(_id)
        isCampaignOwner(projects[_id].parentCampaign)
        lazyStatusUpdaterStart(_id)
    {
        Project storage project = projects[_id];
        Campaign storage campaign = campaigns[project.parentCampaign];

        // Ensure worker is on project
        require(
            checkIsProjectWorker(_id, _worker),
            "Address must be a worker on the project"
        );

        // Ensure project status is not stage
        require(
            project.status != ProjectStatus.Stage,
            "Project must currently be at gate or settled or closed"
        );

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
    )
        internal
        isProjectExisting(_id)
        isCampaignOwner(projects[_id].parentCampaign)
    {
        Project storage project = projects[_id];

        // Ensure worker is on project
        require(
            checkIsProjectWorker(_id, _worker),
            "Address must be a worker on the project"
        );

        // Ensure project status is not stage
        require(
            project.status != ProjectStatus.Stage,
            "Project must currently be at gate or settled or closed"
        );

        // Refund stake
        for (uint256 i = 0; i < project.applications.length; i++) {
            Application storage application = applications[
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
        isProjectExisting(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        lazyStatusUpdaterStart(_id)
        isProjectRunning(_id)
        isMoneyIntended(_stake)
        isMoreThanEnrolStake(_stake)
    {
        Project storage project = projects[_id];
        Campaign storage campaign = campaigns[project.parentCampaign];

        require(!project.applicationRequired, "Project requires applications");
        require(
            !checkIsProjectWorker(_id),
            "Sender must not already be a worker"
        );

        // Creates application to deal with stake
        Application storage application = applications[applicationCount];
        application.metadata = "No Application Required";
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
        isCampaignExisting(projects[_id].parentCampaign)
        isProjectExisting(_id)
        lazyStatusUpdaterStart(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        isProjectRunning(_id)
        isMoneyIntended(_stake)
        isMoreThanEnrolStake(_stake)
        returns (uint256)
    {
        Project storage project = projects[_id];
        require(
            project.applicationRequired,
            "Project does not require applications"
        );

        require(
            !checkIsProjectWorker(_id),
            "Sender must not already be a worker"
        );

        Application storage application = applications[applicationCount];
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
        isProjectExisting(applications[_applicationID].parentProject)
        lazyStatusUpdaterStart(applications[_applicationID].parentProject)
        isCampaignAcceptor(
            projects[applications[_applicationID].parentProject].parentCampaign
        )
        isApplicationExisting(_applicationID)
    {
        Application storage application = applications[_applicationID];
        Project storage project = projects[application.parentProject];
        Campaign storage campaign = campaigns[project.parentCampaign];
        // if project or campaign is closed, decline or if project is past its deadline, decline
        // also refund stake
        if (
            project.status == ProjectStatus.Closed ||
            campaigns[project.parentCampaign].status == CampaignStatus.Closed ||
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
    ) public isCampaignExisting(_id) isCampaignRunning(_id) {
        // Get the campaign
        Campaign storage campaign = campaigns[_id];

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
    ) internal isProjectExisting(_id) {
        Project storage project = projects[_id];
        uint256 thisProjectReward;

        if (project.status == ProjectStatus.Closed) {
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
            TaskStatusFilter.NotClosed
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
            Project storage childProject = projects[childProjectId];

            // If project is NOT closed, then compute rewards
            if (childProject.status != ProjectStatus.Closed) {
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
        Project storage project = projects[_id];

        bool atGate = project.status == ProjectStatus.Gate ||
            project.status == ProjectStatus.Closed;
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
        isProjectExisting(_id)
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        returns (ProjectStatus)
    {
        Project storage project = projects[_id];
        require(
            project.status != ProjectStatus.Closed,
            "Project must be running"
        );
        if (block.timestamp < project.nextMilestone.startStageTimestamp) {
            return ProjectStatus.Settled;
        } else if (block.timestamp < project.nextMilestone.startGateTimestamp) {
            return ProjectStatus.Stage;
        } else if (
            block.timestamp < project.nextMilestone.startSettledTimestamp
        ) {
            return ProjectStatus.Gate;
        } else {
            return ProjectStatus.Settled;
        }
    }

    // Conditions for going to Stage ✅
    function toStageConditions(
        uint256 _id
    )
        public
        view
        isProjectExisting(_id)
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        returns (bool)
    {
        Project storage project = projects[_id];
        Task[] memory notClosedTasks = getTasksOfProjectClosedFilter(
            _id,
            TaskStatusFilter.NotClosed
        );

        bool currentStatusValid = project.status == ProjectStatus.Settled;
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
        isProjectExisting(_id)
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        returns (bool)
    {
        Project storage project = projects[_id];
        Task[] memory notClosedTasks = getTasksOfProjectClosedFilter(
            _id,
            TaskStatusFilter.NotClosed
        );

        bool currentStatusValid = project.status == ProjectStatus.Settled;
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
        isProjectExisting(_id)
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        returns (bool)
    {
        Project storage project = projects[_id];
        bool currentStatusValid = project.status == ProjectStatus.Stage;
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
        isProjectExisting(_id)
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        returns (bool)
    {
        Project storage project = projects[_id];
        bool currentStatusValid = project.status == ProjectStatus.Stage;
        bool stillInStagePeriod = block.timestamp <
            project.nextMilestone.startGateTimestamp;
        bool allTasksHaveSubmissions = true;

        // Ensure all NotClosed tasks have submissions
        Task[] memory notClosedTasks = getTasksOfProjectClosedFilter(
            _id,
            TaskStatusFilter.NotClosed
        );
        for (uint256 i = 0; i < notClosedTasks.length; i++) {
            if (notClosedTasks[i].submission.status == SubmissionStatus.None) {
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
        isProjectExisting(_id)
        isProjectRunning(_id)
        isCampaignRunning(projects[_id].parentCampaign)
        returns (bool)
    {
        Project storage project = projects[_id];

        bool currentStatusValid = project.status == ProjectStatus.Gate;
        bool inSettledPeriod = block.timestamp >=
            project.nextMilestone.startSettledTimestamp;

        return currentStatusValid && inSettledPeriod;
    }

    // Checks that voting conditions are met ✅
    function checkFastForwardStatus(uint256 _id) public view returns (bool) {
        Project storage project = projects[_id];

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
    ) public view returns (Application memory application) {
        Project storage project = projects[_id];
        for (uint256 i = 0; i < project.applications.length; i++) {
            if (applications[project.applications[i]].applicant == _applicant) {
                return applications[project.applications[i]];
            }
        }
    }

    /// ⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️
    /// DEVELOPER FUNCTIONS (ONLY FOR TESTING) 🧑‍💻🧑‍💻🧑‍💻🧑‍💻🧑‍💻
    address public contractMaster;

    constructor() payable {
        contractMaster = payable(msg.sender);
    }

    function contractMasterDrain() public {
        require(
            msg.sender == contractMaster,
            "Only the contract master can drain the contract"
        );
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
