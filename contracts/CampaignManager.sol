// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./FundingsManager.sol";

library CampaignManager {
    using FundingsManager for FundingsManager.Fundings;
    using FundingsManager for FundingsManager.Fundings[];

    struct Campaign {
        // Description of the campaign
        string metadata;
        //CampaignStyle style;
        // Timestamps & status
        uint256 creationTime;
        //uint256 deadline;
        CampaignStatus status;
        // Stakeholders
        address payable creator;
        address payable[] owners;
        address payable[] acceptors;
        address payable[] workers;
        address payable[] allTimeStakeholders;
        // Stake
        FundingsManager.Fundings stake;
        // FundingsManager.Fundings (contains funders)
        FundingsManager.Fundings[] fundings;
        // Child projects & All child projects (contains IDs)
        uint256[] directChildProjects;
        uint256[] allChildProjects;
    }
    // enum CampaignStyle {
    //     Private,
    //     PrivateThenOpen,
    //     Open
    // }

    enum CampaignStatus {
        Running,
        Closed
    }

    // Campaign Creation Function ✅
    function makeCampaign(
        Campaign storage _campaign,
        string memory _metadata,
        // CampaignStyle _style,
        address payable[] memory _owners,
        address payable[] memory _acceptors,
        uint256 _stake,
        uint256 _funding
    ) external {
        _campaign.metadata = _metadata;
        //_campaign.style = _style;
        _campaign.creationTime = block.timestamp;
        //campaign.deadline = _deadline;
        _campaign.status = CampaignStatus.Running;
        _campaign.creator = payable(msg.sender);
        _campaign.owners.push(payable(msg.sender));
        for (uint256 i = 0; i < _owners.length; i++) {
            _campaign.owners.push((_owners[i]));
            _campaign.allTimeStakeholders.push((_owners[i]));
        }
        for (uint256 i = 0; i < _acceptors.length; i++) {
            _campaign.acceptors.push((_acceptors[i]));
            _campaign.allTimeStakeholders.push((_acceptors[i]));
        }
        _campaign.allTimeStakeholders.push(payable(msg.sender));
        _campaign.stake.funder = payable(msg.sender);
        _campaign.stake.funding = _stake;
        _campaign.stake.amountUsed = 0;
        _campaign.stake.fullyRefunded = false;

        if (_funding > 0) {
            FundingsManager.Fundings memory newFunding;
            newFunding.funder = payable(msg.sender);
            newFunding.funding = _funding;
            _campaign.stake.amountUsed = 0;
            newFunding.fullyRefunded = false;
            _campaign.fundings.push(newFunding);
        }
    }

    // Update Campaign Function
    function updateCampaign(
        Campaign storage _campaign,
        string memory _metadata,
        // CampaignStyle _style,
        //uint256 _deadline,
        CampaignManager.CampaignStatus _status,
        address payable[] memory _owners,
        address payable[] memory _acceptors
    ) external {
        _campaign.metadata = _metadata; //✅
        //campaign.style = _style; //❌ (needs all private-to-open effects for transition)
        //campaign.deadline = _deadline; //⚠️ (can't be less than maximum settled time of current stage of contained projects)
        _campaign.status = _status; //⚠️ (can't be closed if there are open projects)
        _campaign.owners = _owners; //✅
        for (uint256 i = 0; i < _owners.length; i++) {
            _campaign.allTimeStakeholders.push((_owners[i]));
        }
        _campaign.acceptors = _acceptors; //✅
        for (uint256 i = 0; i < _acceptors.length; i++) {
            _campaign.allTimeStakeholders.push((_acceptors[i]));
        }
    }

    // Campaign Funding Function ✅
    function fundCampaign(
        Campaign storage _campaign,
        uint256 _funding
    ) external {
        FundingsManager.Fundings memory newFunding;
        newFunding.funder = payable(msg.sender);
        newFunding.funding = _funding;
        _campaign.stake.amountUsed = 0;
        newFunding.fullyRefunded = false;
        _campaign.fundings.push(newFunding);
        _campaign.allTimeStakeholders.push(payable(msg.sender));
    }

    // Refund all campaign fundings ✅
    function refundAllCampaignFundings(Campaign storage _campaign) external {
        for (uint256 i = 0; i < _campaign.fundings.length; i++) {
            FundingsManager.Fundings storage funding = _campaign.fundings[i];

            if (!funding.fullyRefunded) {
                uint256 availableFundsForRefund = funding.funding -
                    funding.amountUsed -
                    funding.amountLocked;
                funding.amountUsed += availableFundsForRefund;
                funding.fullyRefunded = (funding.amountUsed == funding.funding);
                payable(msg.sender).transfer(availableFundsForRefund);
            }
        }
    }

    // Refund own funding ✅
    function refundOwnFunding(
        Campaign storage _campaign,
        uint256 _fundingID
    ) external {
        FundingsManager.Fundings storage funding = _campaign.fundings[
            _fundingID
        ];

        require(!funding.fullyRefunded, "Funding must not be fully refunded");
        require(funding.funder == msg.sender, "Sender must be the funder");

        uint256 availableFundsForRefund = funding.funding -
            funding.amountUsed -
            funding.amountLocked;
        funding.amountUsed += availableFundsForRefund;
        funding.fullyRefunded = (funding.amountUsed == funding.funding);
        payable(msg.sender).transfer(availableFundsForRefund);
    }

    // Refund closed Campaign stake ✅
    function refundStake(Campaign storage _campaign) external {
        if (_campaign.status == CampaignStatus.Closed) {
            _campaign.stake.amountUsed = _campaign.stake.funding;
            _campaign.stake.fullyRefunded = true;
            _campaign.creator.transfer(_campaign.stake.funding);
        }
    }
}
