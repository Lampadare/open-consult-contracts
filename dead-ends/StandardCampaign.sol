// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./Utilities.sol";
import "./FundingsManager.sol";

contract StandardCampaign {
    using Utilities for uint256[];
    using Utilities for address[];
    using Utilities for address payable[];
    using FundingsManager for Fundings[];

    /// ⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️
    /// STRUCTS DECLARATIONS
    struct Campaign {
        // Description of the campaign
        string title;
        string metadata;
        CampaignStyle style;
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
        Fundings stake;
        // Fundings (contains funders)
        Fundings[] fundings;
        // Child projects & All child projects (contains IDs)
        uint256[] directChildProjects;
        uint256[] allChildProjects;
    }

    // Mapping of campaign IDs to campaigns, IDs are numbers starting from 0
    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCount = 0;

    enum CampaignStyle {
        Private,
        PrivateThenOpen,
        Open
    }

    enum CampaignStatus {
        Running,
        Closed
    }

    // Minimum stake required to create a Private campaign
    uint256 public minStake = 0.0025 ether;
    // Minimum stake required to create an Open Campaign
    uint256 public minOpenCampaignStake = 0.025 ether;

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

    /// ⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️⬜️
    /// CAMPAIGN WRITE FUNCTIONS 🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻
    // Create a new campaign, optionally fund it ✅
    function makeCampaign(
        string memory _title,
        string memory _metadata,
        CampaignStyle _style,
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
        //PRIVATE CAMPAIGN REQ (open campaigns don't have deadlines)
        if (_stake >= minStake) {
            Campaign storage campaign = campaigns[campaignCount];

            campaign.title = _title;
            campaign.metadata = _metadata;
            campaign.style = _style;
            campaign.creationTime = block.timestamp;
            //campaign.deadline = _deadline;
            campaign.status = CampaignStatus.Running;
            campaign.creator = payable(msg.sender);
            campaign.owners.push(payable(msg.sender));
            for (uint256 i = 0; i < _owners.length; i++) {
                campaign.owners.push((_owners[i]));
                campaign.allTimeStakeholders.push((_owners[i]));
            }
            for (uint256 i = 0; i < _acceptors.length; i++) {
                campaign.acceptors.push((_acceptors[i]));
                campaign.allTimeStakeholders.push((_acceptors[i]));
            }
            campaign.allTimeStakeholders.push(payable(msg.sender));
            campaign.stake.funder = payable(msg.sender);
            campaign.stake.funding = _stake;
            campaign.stake.amountUsed = 0;
            campaign.stake.fullyRefunded = false;

            if (_funding > 0) {
                Fundings memory newFunding;
                newFunding.funder = payable(msg.sender);
                newFunding.funding = _funding;
                campaign.stake.amountUsed = 0;
                newFunding.fullyRefunded = false;
                campaign.fundings.push(newFunding);
            }

            campaignCount++;
            return campaignCount - 1;
        }
    }

    // Donate to a campaign ✅
    function fundCampaign(
        uint256 _id,
        uint256 _funding
    ) public payable isMoneyIntended(_funding) {
        Fundings memory newFunding;
        newFunding.funder = payable(msg.sender);
        newFunding.funding = _funding;
        newFunding.amountUsed = 0;
        newFunding.fullyRefunded = false;

        Campaign storage campaign = campaigns[_id];
        campaign.fundings.push(newFunding);
    }

    // Refund all campaign fundings ✅
    function refundAllCampaignFundings(
        uint256 _id,
        bool _drainCampaign
    ) public isCampaignExisting(_id) isCampaignOwner(_id) {
        require(_drainCampaign == true, "Just double checking.");

        Campaign storage campaign = campaigns[_id];

        for (uint256 i = 0; i < campaign.fundings.length; i++) {
            Fundings storage funding = campaign.fundings[i];

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

    // Refund own funder funding ✅
    function refundOwnFunding(
        uint256 _id,
        uint256 _fundingID
    ) public isCampaignExisting(_id) isCampaignFunder(_id) {
        Campaign storage campaign = campaigns[_id];
        Fundings storage funding = campaign.fundings[_fundingID];

        require(funding.funder == msg.sender, "Sender must be the funder");
        require(!funding.fullyRefunded, "Funding must not be fully refunded");

        uint256 availableFundsForRefund = funding.funding -
            funding.amountUsed -
            funding.amountLocked;
        funding.amountUsed += availableFundsForRefund;
        funding.fullyRefunded = (funding.amountUsed == funding.funding);
        payable(msg.sender).transfer(availableFundsForRefund);
    }

    // Refund closed campaign stake ✅
    function refundStake(uint256 _id) public isCampaignCreator(_id) {
        Campaign storage campaign = campaigns[_id];
        if (campaign.status == CampaignStatus.Closed) {
            campaign.stake.amountUsed = campaign.stake.funding;
            campaign.stake.fullyRefunded = true;
            campaign.creator.transfer(campaign.stake.funding);
        }
    }

    // Update Campaign ⚠️
    function updateCampaign(
        uint256 _id,
        string memory _title,
        string memory _metadata,
        // CampaignStyle _style,
        uint256 _deadline,
        CampaignStatus _status,
        address payable[] memory _owners,
        address payable[] memory _acceptors
    ) public isCampaignOwner(_id) isFutureTimestamp(_deadline) {
        require(
            _owners.length > 0,
            "Campaign must have at least one owner at all times"
        );
        if (_status == CampaignStatus.Closed) {
            // require that all projects inside are closed
            for (
                uint256 i = 0;
                i < campaigns[_id].allChildProjects.length;
                i++
            ) {
                require(
                    projects[campaigns[_id].allChildProjects[i]].status ==
                        ProjectStatus.Closed,
                    "Projects must be closed"
                );
            }
        }

        Campaign storage campaign = campaigns[_id];

        campaign.title = _title; //
        campaign.metadata = _metadata; //
        //campaign.style = _style; //❌ (needs all private-to-open effects for transition)
        //campaign.deadline = _deadline; //⚠️ (can't be less than maximum settled time of current stage of contained projects)
        campaign.status = _status; //⚠️ (can't be closed if there are open projects)
        campaign.owners = _owners; //
        campaign.acceptors = _acceptors; //
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

    // Cleanup all tasks that are not closed at the right time for all projects ⚠️
    function cleanUpNotClosedTasksForAllProjects(uint256 _id) internal {
        Campaign storage campaign = campaigns[_id];
        for (uint256 i = 0; i < campaign.allChildProjects.length; i++) {
            cleanUpNotClosedTasks(campaign.allChildProjects[i]);
        }
    }

    // Unlock the funds for all projects that can have their funds unlocked ⚠️
    function unlockTheFundsForAllProjectsPostCleanup(uint256 _id) internal {
        Campaign storage campaign = campaigns[_id];
        for (uint256 i = 0; i < campaign.allChildProjects.length; i++) {
            unlockTheFundsForProjectPostCleanup(campaign.allChildProjects[i]);
        }
    }

    // Compute rewards for all projects and tasks in a campaign ⚠️
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

    /// 🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳🔳
    /// CAMPAIGN READ FUNCTIONS 🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹
    // Get all campaigns
    function getAllCampaigns() public view returns (Campaign[] memory) {
        Campaign[] memory _campaigns = new Campaign[](campaignCount);
        for (uint256 i = 0; i < campaignCount; i++) {
            _campaigns[i] = campaigns[i];
        }
        return _campaigns;
    }

    // Get campaign by ID
    function getCampaignByID(
        uint256 _id
    ) public view returns (Campaign memory) {
        return campaigns[_id];
    }

    // Get campaign Fundings struct array
    function getFundingsOfCampaign(
        uint256 _id
    ) public view returns (Fundings[] memory) {
        return campaigns[_id].fundings;
    }

    // Get the total funding of a campaign
    function getCampaignTotalFunding(
        uint256 _id
    ) public view isCampaignExisting(_id) returns (uint256) {
        Campaign memory campaign = campaigns[_id];
        uint256 totalFunding = 0;
        for (uint256 i = 0; i < campaign.fundings.length; i++) {
            totalFunding += campaign.fundings[i].funding;
        }
        return totalFunding;
    }

    // Get the total unused balance of a campaign
    function getCampaignUnusedBalance(
        uint256 _id
    ) public view isCampaignExisting(_id) returns (uint256) {
        Campaign memory campaign = campaigns[_id];
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < campaign.fundings.length; i++) {
            if (!campaign.fundings[i].fullyRefunded) {
                uint256 balanceOfFundingStruct = campaign.fundings[i].funding -
                    campaign.fundings[i].amountUsed;
                totalBalance += balanceOfFundingStruct;
            }
        }
        return totalBalance;
    }

    // Get the total locked rewards of a campaign
    function getCampaignLockedRewards(
        uint256 _id
    ) public view isCampaignExisting(_id) returns (uint256) {
        Campaign memory campaign = campaigns[_id];
        uint256 totalLockedRewards = 0;
        for (uint256 i = 0; i < campaign.fundings.length; i++) {
            if (!campaign.fundings[i].fullyRefunded) {
                totalLockedRewards += campaign.fundings[i].amountLocked;
            }
        }
        return totalLockedRewards;
    }

    // Get the total EFFECTIVE balance (unused - locked) of a campaign
    function getEffectiveCampaignBalance(
        uint256 _id
    ) public view isCampaignExisting(_id) returns (uint256) {
        return getCampaignUnusedBalance(_id) - getCampaignLockedRewards(_id);
    }

    // Check if sender is owner of campaign
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

    // Overloading: Check if address is owner of campaign
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

    // Check if sender is acceptor of campaign
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

    // Overloading: Check if address is acceptor of campaign
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
