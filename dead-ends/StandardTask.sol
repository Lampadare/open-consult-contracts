// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./Utilities.sol";
import "./FundingsManager.sol";

contract StandardCampaign {
    using Utilities for uint256[];
    using Utilities for address[];
    using Utilities for address payable[];
    using FundingsManager for Fundings[];

    struct Task {
        // Description of the task
        string title;
        string metadata;
        // Contribution weight
        uint256 weight;
        uint256 reward;
        bool paid;
        // Timestamps
        uint256 creationTime;
        uint256 deadline;
        // Worker
        address payable worker;
        // Completion
        Submission submission;
        bool closed;
        // Parent Campaign & Project (contains IDs)
        uint256 parentProject;
    }

    // Mapping of task IDs to tasks, IDs are numbers starting from 0
    mapping(uint256 => Task) public tasks;
    uint256 public taskCount = 0;

    struct Submission {
        string metadata;
        SubmissionStatus status;
    }

    enum TaskStatusFilter {
        NotClosed,
        Closed,
        All
    }

    enum SubmissionStatus {
        None,
        Pending,
        Accepted,
        Declined,
        Disputed
    }

    /// ⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️
    /// MODIFIERS
    // Timestamps
    modifier isFutureTimestamp(uint256 timestamp) {
        require(timestamp > block.timestamp, "Timestamp must be in the future");
        _;
    }

    // Does it exist?
    modifier isCampaignExisting(uint256 _id) {
        require(_id < campaignCount, "Campaign does not exist");
        _;
    }
    modifier isProjectExisting(uint256 _id) {
        require(_id < projectCount, "Project does not exist");
        _;
    }
    modifier isTaskExisting(uint256 _id) {
        require(_id < taskCount, "Task does not exist");
        _;
    }
    modifier isApplicationExisting(uint256 _id) {
        require(_id < applicationCount, "Application does not exist");
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

    // Cleanup all tasks that are not closed at the right time for all projects ✅
    function cleanUpNotClosedTasksForAllProjects(uint256 _id) internal {
        Campaign storage campaign = campaigns[_id];
        for (uint256 i = 0; i < campaign.allChildProjects.length; i++) {
            cleanUpNotClosedTasks(campaign.allChildProjects[i]);
        }
    }

    // Unlock the funds for all projects that can have their funds unlocked ✅
    function unlockTheFundsForAllProjectsPostCleanup(uint256 _id) internal {
        Campaign storage campaign = campaigns[_id];
        for (uint256 i = 0; i < campaign.allChildProjects.length; i++) {
            unlockTheFundsForProjectPostCleanup(campaign.allChildProjects[i]);
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

    /// ⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️
    /// TASK WRITE FUNCTIONS 🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻
    // Create a new task
    function makeTask(
        string memory _title,
        string memory _metadata,
        uint256 weight,
        uint256 _deadline,
        uint256 _parentProjectID
    )
        public
        isCampaignExisting(projects[_parentProjectID].parentCampaign)
        isProjectExisting(_parentProjectID)
        isCampaignOwner(projects[_parentProjectID].parentCampaign)
        returns (uint256)
    {
        require(_deadline > block.timestamp, "Deadline must be in the future");

        Task storage task = tasks[taskCount];

        task.title = _title;
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
        isTaskExisting(_id)
        isProjectExisting(tasks[_id].parentProject)
        lazyStatusUpdaterStart(tasks[_id].parentProject)
        isProjectRunning(tasks[_id].parentProject)
        isWorkerOnTask(_id)
        isTaskNotClosed(_id)
        isProjectStage(tasks[_id].parentProject)
    {
        Task storage task = tasks[_id];
        require(task.deadline > block.timestamp, "Task deadline has passed");

        // Create submission, if it already exists, overwrite it
        Submission storage submission = task.submission;
        // Attach the IPFS hash for metadata
        submission.metadata = _metadata;
        // Submission status is pending after submission
        submission.status = SubmissionStatus.Pending;
    }

    // Submission decision by acceptors ✅
    function submissionDecision(
        uint256 _id,
        bool _accepted
    )
        public
        isTaskExisting(_id)
        isProjectExisting(tasks[_id].parentProject)
        lazyStatusUpdaterStart(tasks[_id].parentProject)
        isProjectRunning(tasks[_id].parentProject)
        isCampaignAcceptor(projects[tasks[_id].parentProject].parentCampaign)
        isTaskNotClosed(_id)
        isProjectGate(tasks[_id].parentProject)
    {
        Project storage project = projects[tasks[_id].parentProject];
        // Campaign storage campaign = campaigns[project.parentCampaign];
        Task storage task = tasks[_id];
        Submission storage submission = task.submission;

        require(
            block.timestamp <
                project.nextMilestone.startGateTimestamp +
                    taskSubmissionDecisionTime,
            "Decision must happen during decision window"
        );
        require(
            submission.status == SubmissionStatus.Pending,
            "Submission must not already have decision"
        );

        // If decision is accepted, set submission status to accepted,
        // payout worker, update locked rewards and close task
        if (_accepted) {
            submission.status = SubmissionStatus.Accepted;
            task.paid = true;
            task.closed = true;
            task.worker.transfer(task.reward);
            //campaign.lockedRewards -= task.reward;
        } else {
            submission.status = SubmissionStatus.Declined;
        }
    }

    // Automatically accept decisions which have not received a submission and are past the decision time ✅
    // Also automatically close tasks which have received declined submissions
    // and weren't disputed within the dispute time
    function cleanUpNotClosedTasks(uint256 _id) internal {
        Project storage project = projects[_id];
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
            TaskStatusFilter.NotClosed
        );

        for (uint256 i = 0; i < notClosedTaskIds.length; i++) {
            Task storage task = tasks[notClosedTaskIds[i]];
            if (task.submission.status == SubmissionStatus.Pending) {
                task.submission.status = SubmissionStatus.Accepted;
                task.closed = true;
                task.paid = true;
                task.worker.transfer(task.reward);
                //campaign.lockedRewards -= task.reward;
            }

            if (
                task.submission.status == SubmissionStatus.Declined &&
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
        Project storage project = projects[_id];

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
    function workerSelfAssignsTask(
        uint256 _id
    )
        public
        isTaskExisting(_id)
        isProjectExisting(tasks[_id].parentProject)
        lazyStatusUpdaterStart(tasks[_id].parentProject)
        isTaskNotClosed(_id)
    {
        Task storage task = tasks[_id];
        Project storage project = projects[task.parentProject];

        require(
            project.status == ProjectStatus.Settled &&
                checkIsProjectWorker(_id),
            "Project must be settled"
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
        isTaskExisting(_id)
        isProjectExisting(tasks[_id].parentProject)
        lazyStatusUpdaterStart(tasks[_id].parentProject)
        isProjectRunning(tasks[_id].parentProject)
        isWorkerOnTask(_id)
        isTaskNotClosed(_id)
        isProjectGate(tasks[_id].parentProject)
    {
        Task storage task = tasks[_id];
        Project storage project = projects[task.parentProject];
        Submission storage submission = task.submission;

        require(
            submission.status == SubmissionStatus.Declined,
            "Submission must be declined"
        );
        require(
            block.timestamp <
                project.nextMilestone.startGateTimestamp +
                    taskSubmissionDecisionDisputeTime,
            "Dispute must happen during dispute window"
        );

        submission.status = SubmissionStatus.Disputed;
        task.closed = true;
        task.paid = false;

        dispute(_id, _metadata);
    }

    /// 🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳
    /// TASK READ FUNCTIONS 🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹

    // How many tasks match filter? helper function for getTasksOfProjectClosedFilter() below✅
    function countTasksWithFilter(
        uint256 _id,
        TaskStatusFilter _statusFilter
    ) internal view returns (uint256) {
        uint256 taskCounter = 0;
        uint256[] memory childTasks = projects[_id].childTasks;
        for (uint256 i = 0; i < childTasks.length; i++) {
            if (
                _statusFilter == TaskStatusFilter.Closed &&
                tasks[childTasks[i]].closed
            ) {
                taskCounter++;
            } else if (
                _statusFilter == TaskStatusFilter.NotClosed &&
                !tasks[childTasks[i]].closed
            ) {
                taskCounter++;
            } else if (_statusFilter == TaskStatusFilter.All) {
                taskCounter++;
            }
        }
        return taskCounter;
    }

    // Get tasks in a project based on Closed/NotClosed filter✅
    function getTasksOfProjectClosedFilter(
        uint256 _id,
        TaskStatusFilter _statusFilter
    ) public view returns (Task[] memory) {
        Project memory parentProject = projects[_id];
        if (_statusFilter == TaskStatusFilter.NotClosed) {
            // Get uncompleted tasks
            Task[] memory _tasks = new Task[](
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
        } else if (_statusFilter == TaskStatusFilter.Closed) {
            // Get completed tasks
            Task[] memory _tasks = new Task[](
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
            Task[] memory _tasks = new Task[](parentProject.childTasks.length);
            for (uint256 i = 0; i < parentProject.childTasks.length; i++) {
                _tasks[i] = tasks[parentProject.childTasks[i]];
            }
            return _tasks;
        }
    }

    // Get task IDs in a project based on Closed/NotClosed filter✅
    function getTaskIdsOfProjectClosedFilter(
        uint256 _id,
        TaskStatusFilter _statusFilter
    ) public view returns (uint256[] memory) {
        Project memory parentProject = projects[_id];
        if (_statusFilter == TaskStatusFilter.NotClosed) {
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
        } else if (_statusFilter == TaskStatusFilter.Closed) {
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
