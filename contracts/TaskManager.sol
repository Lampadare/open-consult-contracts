// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./FundingsManager.sol";

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
}
