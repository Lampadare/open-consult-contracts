// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./CampaignManager.sol";
import "./ProjectManager.sol";
import "./TaskManager.sol";
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
    using ProjectManager for ProjectManager.Application;
    using TaskManager for TaskManager.Task;

    /// DEVELOPER FUNCTIONS (ONLY FOR TESTING) 🧑‍💻🧑‍💻🧑‍💻🧑‍💻🧑‍💻
    address public contractMaster;
    event Dispute(uint256 _id, string _metadata);

    constructor() payable {
        contractMaster = payable(msg.sender);
    }

    function contractMasterDrain() public {
        require(msg.sender == contractMaster, "E45");
        payable(msg.sender).transfer(address(this).balance);
    }

    function dispute(uint256 _id, string memory _metadata) public {
        emit Dispute(_id, _metadata);
    }

    // Mapping of campaign IDs to campaigns, IDs are numbers starting from 0
    mapping(uint256 => CampaignManager.Campaign) public campaigns;
    uint256 public campaignCount;

    // Mapping of project IDs to projects, IDs are numbers starting from 0
    mapping(uint256 => ProjectManager.Project) public projects;
    uint256 public projectCount;

    // Mapping of task IDs to tasks, IDs are numbers starting from 0
    mapping(uint256 => TaskManager.Task) public tasks;
    uint256 public taskCount;

    // Mapping of task IDs to tasks, IDs are numbers starting from 0
    mapping(uint256 => ProjectManager.Application) public applications;
    uint256 public applicationCount;

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

    // Campaign Statuses
    modifier isCampaignRunning(uint256 _id) {
        require(
            campaigns[_id].status == CampaignManager.CampaignStatus.Running,
            "E8"
        );
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
    /// UPDATER FUNCTIONS ★👀★👀★👀★👀★👀★👀★👀★👀★👀★👀★👀★👀★👀★👀★👀★👀★👀★👀★👀★👀★👀★

    // Figure out where we are and where we should be and fix is needed ✅
    function statusFixer(uint256 _id) public {
        ProjectManager.Project storage project = projects[_id];

        // If we are where we should be and votes allow to fast forward, try to fast forward
        // Otherwise, do nothing
        if (
            projects[_id].whatStatusProjectShouldBeAt() == project.status &&
            checkFastForwardStatus(_id)
        ) {
            updateProjectStatus(_id);
        }

        // If we should be in settled but are in gate, then return
        // moving to settled needs owner input so we'll just wait here
        if (
            projects[_id].whatStatusProjectShouldBeAt() ==
            ProjectManager.ProjectStatus.Settled &&
            project.status == ProjectManager.ProjectStatus.Gate
        ) {
            cleanUpNotClosedTasksForAllProjects(project.parentCampaign);
            unlockTheFundsForAllProjectsPostCleanup(project.parentCampaign);
            computeAllRewardsInCampaign(project.parentCampaign);
            return;
        } else {
            // Iterate until we get to where we should be
            while (
                projects[_id].whatStatusProjectShouldBeAt() != project.status
            ) {
                updateProjectStatus(_id);
                if (project.status == ProjectManager.ProjectStatus.Gate) {
                    break;
                }
            }
            cleanUpNotClosedTasksForAllProjects(project.parentCampaign);
            unlockTheFundsForAllProjectsPostCleanup(project.parentCampaign);
            computeAllRewardsInCampaign(project.parentCampaign);
        }
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
            (bool toStage, bool toStageFastForward) = toStageConditions(_id);
            if (toStageFastForward) {
                // update project status
                project.status = ProjectManager.ProjectStatus.Stage;
                // delete all votes
                delete project.fastForward;
                return;
            } else if (toStage) {
                // adjust lateness
                adjustLatenessBeforeStage(_id);
                // update project status
                project.status = ProjectManager.ProjectStatus.Stage;
                // delete all votes
                delete project.fastForward;
                return;
            }
        }
        // GOING INTO GATE 🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹
        else if (project.status == ProjectManager.ProjectStatus.Stage) {
            (bool toGate, bool toGateFastForward) = toGateConditions(_id);
            if (toGateFastForward) {
                // update project status
                project.status = ProjectManager.ProjectStatus.Gate;
                // delete all votes
                delete project.fastForward;
                return;
            } else if (toGate) {
                // update project status
                project.status = ProjectManager.ProjectStatus.Gate;
                // delete all votes
                delete project.fastForward;
                return;
            }
        }
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

    // Unlock amounts of funds by going through each funding and unlocking until the expense is covered ✅
    function fundUnlockAmount(uint256 _id, uint256 _expense) internal {
        checkCampaignExists(_id);
        CampaignManager.Campaign storage campaign = campaigns[_id];
        campaign.fundings.fundUnlockAmount(_expense);
    }

    // Conditions for going to Stage ✅
    function toStageConditions(uint256 _id) public view returns (bool, bool) {
        ProjectManager.Project storage project = projects[_id];

        bool currentStatusValid = project.status ==
            ProjectManager.ProjectStatus.Settled;
        bool projectHasWorkers = project.workers.length > 0;
        bool allTasksHaveWorkers = true;
        bool inStagePeriod = block.timestamp >=
            project.nextMilestone.startStageTimestamp;

        // For fast forward
        bool stillInSettledPeriod = block.timestamp <
            project.nextMilestone.startStageTimestamp;

        // Ensure all tasks have workers
        for (uint256 i = 0; i < project.childTasks.length; i++) {
            if (tasks[project.childTasks[i]].worker == address(0)) {
                allTasksHaveWorkers = false;
                return (false, false);
            }
        }

        // All conditions must be true to go to stage
        return (
            currentStatusValid && projectHasWorkers && inStagePeriod,
            currentStatusValid &&
                projectHasWorkers &&
                stillInSettledPeriod &&
                checkFastForwardStatus(_id)
        );
    }

    // Conditions for going to Gate ✅
    function toGateConditions(uint256 _id) public view returns (bool, bool) {
        checkProjectExists(_id);
        ProjectManager.Project storage project = projects[_id];
        bool currentStatusValid = project.status ==
            ProjectManager.ProjectStatus.Stage;
        bool inGatePeriod = block.timestamp >=
            project.nextMilestone.startGateTimestamp;

        // For fast forward
        bool stillInStagePeriod = block.timestamp <
            project.nextMilestone.startGateTimestamp;
        bool allTasksHaveSubmissions = true;

        for (uint256 i = 0; i < project.childTasks.length; i++) {
            if (
                tasks[project.childTasks[i]].submission.status ==
                TaskManager.SubmissionStatus.None
            ) {
                allTasksHaveSubmissions = false;
            }
        }

        return (
            currentStatusValid && inGatePeriod,
            currentStatusValid &&
                stillInStagePeriod &&
                allTasksHaveSubmissions &&
                checkFastForwardStatus(_id)
        );
    }

    // Adjust lateness of Project before stage ✅
    function adjustLatenessBeforeStage(uint256 _id) internal {
        checkProjectExists(_id);
        ProjectManager.Project storage project = projects[_id];
        uint256 lateness = 0;

        // If we are late, add lateness to all tasks and nextmilestone
        if (block.timestamp > project.nextMilestone.startStageTimestamp) {
            lateness =
                block.timestamp -
                project.nextMilestone.startStageTimestamp;
        }

        // Add lateness to all tasks
        for (uint256 i = 0; i < project.childTasks.length; i++) {
            TaskManager.Task storage task = tasks[project.childTasks[i]];
            if (!task.closed) {
                task.deadline += lateness; // add lateness to deadline
            }
        }

        // add lateness to nextmilestone
        project.nextMilestone.startGateTimestamp += lateness;
        project.nextMilestone.startSettledTimestamp += lateness;
    }

    // Update project milestones 📍
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

    // Compute rewards for all projects and tasks in a campaign ✅
    function computeAllRewardsInCampaign(
        uint256 _id
    ) public isCampaignRunning(_id) {
        checkCampaignExists(projects[_id].parentCampaign);
        // Get the campaign
        CampaignManager.Campaign storage campaign = campaigns[_id];

        // unlock the funds of the project -> inside check we're past decision time and dispute time

        // Loop over all direct projects in the campaign
        for (uint256 i = 0; i < campaign.directChildProjects.length; i++) {
            uint256 projectId = campaign.directChildProjects[i];

            // Compute rewards for the project and its tasks recursively
            computeProjectRewards(projectId, campaign.getEffectiveBalance());
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

        // Updating tasks requires reward conditions to be met
        if (updateProjectRewardsConditions(_id)) {
            for (uint256 i = 0; i < project.childTasks[i]; i++) {
                TaskManager.Task storage task = tasks[project.childTasks[i]];
                // Compute the reward for each task at this level)
                // Compute the reward based on the task's weight and the total weight
                uint256 taskReward = (thisProjectReward * task.weight) / 1000;

                // Update the task reward in storage
                task.reward = taskReward;
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

    // Automatically accept decisions which have not received a submission and are past the decision time ✅
    // Also automatically close tasks which have received declined submissions
    // and weren't disputed within the dispute time
    function cleanUpNotClosedTasks(uint256 _id) internal {
        ProjectManager.Project storage project = projects[_id];
        CampaignManager.Campaign storage campaign = campaigns[
            project.parentCampaign
        ];

        for (uint256 i = 0; i < project.childTasks.length; i++) {
            TaskManager.Task storage task = tasks[project.childTasks[i]];
            task.cleanupNotClosedTasks(
                campaign,
                project.nextMilestone.startGateTimestamp,
                taskSubmissionDecisionTime,
                taskSubmissionDecisionDisputeTime
            );
        }
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
        returns (uint256)
    {
        require(_stake >= minStake, "E46");
        CampaignManager.Campaign storage campaign = campaigns[campaignCount];
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
            campaign.refundStake();
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

    // Close project ✅
    function closeProject(
        uint256 _id
    ) public isCampaignOwner(projects[_id].parentCampaign) {
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

        CampaignManager.Campaign storage parentCampaign = campaigns[
            projects[_id].parentCampaign
        ];
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

        // Get latest task deadline
        uint256 latestTaskDeadline = 0;
        for (uint256 i = 0; i < project.childTasks.length; i++) {
            if (
                tasks[project.childTasks[i]].deadline > latestTaskDeadline &&
                !tasks[project.childTasks[i]].closed
            ) {
                latestTaskDeadline = tasks[project.childTasks[i]].deadline;
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
        for (uint256 i = 0; i < project.childTasks.length; i++) {
            TaskManager.Task storage task = tasks[project.childTasks[i]];
            // Clear workers of unclosed tasks when going settled
            task.worker = payable(address(0));
            // If task deadline is before timestamp of stage start and uncompleted
            if (task.deadline < project.nextMilestone.startStageTimestamp) {
                task.deadline = Utilities.max(
                    latestTaskDeadline,
                    project.nextMilestone.startGateTimestamp - 1 seconds
                );
            }
        }

        // Lock funds for the project
        parentCampaign.fundings.fundLockAmount(project.reward);

        // Update project status
        project.status = ProjectManager.ProjectStatus.Settled;

        // Clear fast forward votes
        delete project.fastForward;
    }

    /// ⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️
    /// PROJECT WRITE FUNCTIONS 🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻
    // Create a new project ✅
    function makeProject(
        string memory _metadata,
        // uint256 _deadline,
        bool _applicationRequired,
        uint256 _parentCampaignId,
        uint256 _parentProjectId,
        bool _topLevel
    ) public returns (uint256) {
        checkCampaignExists(_parentCampaignId);
        require(_parentProjectId <= projectCount + 1, "E21");

        ProjectManager.Project storage project = projects[projectCount];
        CampaignManager.Campaign storage parentCampaign = campaigns[
            _parentCampaignId
        ];

        project.makeProject(
            _metadata,
            // _deadline,
            _applicationRequired,
            _parentCampaignId
        );

        // If this is a top level project, set the parent project to itself
        if (_topLevel) {
            projects[projectCount].parentProject = projectCount;
            // In the PARENTS of THIS project being created, add THIS project to the child projects
            // If this is a top level project, add it in the parent campaign direct child projects
            parentCampaign.directChildProjects.push(projectCount);
            parentCampaign.allChildProjects.push(projectCount);
        } else {
            projects[projectCount].parentProject = _parentProjectId;
            // In the PARENTS of THIS project being created, add THIS project to the child projects
            // If this is not the top level project, add it to the parent project all child projects
            // Reference project in campaign
            parentCampaign.allChildProjects.push(projectCount);
        }

        projectCount++;
        return projectCount - 1;
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
    function workerDropOut(uint256 _projectId, uint256 _applicationId) public {
        checkProjectExists(_projectId);
        statusFixer(_projectId);

        ProjectManager.Project storage project = projects[_projectId];
        ProjectManager.Application storage application = applications[
            _applicationId
        ];

        project.workerDropOut(application, _applicationId);
    }

    // Remove worker from project by owner 📍
    function fireWorker(
        uint256 _projectId,
        uint256 _applicationId
    ) public isCampaignOwner(projects[_projectId].parentCampaign) {
        checkProjectExists(_projectId);
        // isOwner?
        statusFixer(_projectId);
        ProjectManager.Project storage project = projects[_projectId];
        ProjectManager.Application storage application = applications[
            _applicationId
        ];

        project.fireWorker(application, _applicationId);
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

        // Get structs
        ProjectManager.Project storage project = projects[_id];
        CampaignManager.Campaign storage campaign = campaigns[
            project.parentCampaign
        ];
        ProjectManager.Application storage application = applications[
            applicationCount
        ];

        // Can't be a worker already
        require(!project.checkIsProjectWorker(), "E34");

        // Create application
        project.workerEnrolNoApplication(
            campaign,
            application,
            _id,
            applicationCount
        );

        applicationCount++;
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
        ProjectManager.Application storage application = applications[
            applicationCount
        ];

        require(!project.checkIsProjectWorker(), "E36");

        project.applyToProject(application, _metadata, _id, applicationCount);

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

        ProjectManager.Application storage application = applications[
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
            application.accepted = true;
            // deleteItemInUintArray(_applicationID, project.applications); maybe?? -> only on refund
        }
    }

    /// 🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳
    /// PROJECT READ FUNCTIONS 🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹

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

        task.worker = payable(msg.sender);

        // If stake by sender is strictly superior than stake of current worker on task
        // then remove current worker from task and assign sender to task
        // if (task.worker != address(0)) {
        //     if (
        //         getApplicationByApplicant(_id, task.worker).enrolStake.funding <
        //         getApplicationByApplicant(_id, msg.sender).enrolStake.funding
        //     ) {
        //         // Remove worker from task
        //         task.worker = payable(address(0));
        //         // Assign sender to task
        //         task.worker = payable(msg.sender);
        //         return;
        //     } else {
        //         return;
        //     }
        // } else {
        // Assign sender to task
        //}
    }

    // // Get the application of a worker on a project by their address 📍
    // function getApplicationByApplicant(
    //     uint256 _id,
    //     address _applicant
    // ) public view returns (ProjectManager.Application memory application) {
    //     ProjectManager.Project storage project = projects[_id];
    //     for (uint256 i = 0; i < project.applications.length; i++) {
    //         if (applications[project.applications[i]].applicant == _applicant) {
    //             return applications[project.applications[i]];
    //         }
    //     }
    // }

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

    receive() external payable {}

    fallback() external payable {}
}
