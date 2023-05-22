// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./FundingsManager.sol";
import "./CampaignManager.sol";

library TaskManager {
    struct Task {
        // Description of the task
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

    struct Submission {
        string metadata;
        SubmissionStatus status;
    }

    enum SubmissionStatus {
        None,
        Pending,
        Accepted,
        Declined,
        Disputed
    }

    enum TaskStatusFilter {
        NotClosed,
        Closed,
        All
    }

    function cleanupNotClosedTasks(
        Task storage _task,
        CampaignManager.Campaign storage _campaign,
        uint256 _startGateTimestamp,
        uint256 _taskSubmissionDecisionTime,
        uint256 _taskSubmissionDecisionDisputeTime
    ) external {
        // Must be in the correct decision time window
        require(
            block.timestamp > _startGateTimestamp + _taskSubmissionDecisionTime,
            "E47"
        );
        // If the task is not closed
        if (!_task.closed) {
            // If the task received submission and the decision time window has passed
            // but the submission is still pending, accept it, close it and pay the worker
            if (_task.submission.status == SubmissionStatus.Pending) {
                _task.submission.status = SubmissionStatus.Accepted;
                _task.closed = true;
                _task.paid = true;
                _task.worker.transfer(_task.reward);
                FundingsManager.fundUseAmount(_campaign.fundings, _task.reward);
            }

            // If the task received submission, which was declined and the dispute time window
            // has passed, decline it, close it and unlock the funds
            if (
                _task.submission.status ==
                TaskManager.SubmissionStatus.Declined &&
                block.timestamp >=
                _startGateTimestamp + _taskSubmissionDecisionDisputeTime
            ) {
                _task.closed = true;
                _task.paid = false;
                FundingsManager.fundUnlockAmount(
                    _campaign.fundings,
                    _task.reward
                );
            }
        }
    }
}
