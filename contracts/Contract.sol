// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";

interface IERC721 {
    function safeMint(address, string memory) external;
}

contract Crowdfund is AccessControl {
    struct Campaign {
        address owner;
        uint256 target;
        uint256 startAt;
        uint256 endAt;
        uint256 amountCollected;
        bool collected;
        address[] donators;
        uint256[] donations;
        string metadata;
    }

    // Mappings for Retriving Information
    mapping(uint256 => Campaign) public campaigns;

    // State Variables
    uint256 public campaignCount = 0;
    address owner;
    IERC721 public nft;
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR");

    // Events

    event CreateCampaign(
        address owner,
        uint256 target,
        uint256 startAt,
        uint256 endAt
    );

    event DonateToCampaign(address donator, uint256 amount, uint256 campaignId);

    event Withdraw(uint256 id, uint256 amount);

    constructor(address _nft) {
        nft = IERC721(_nft);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function addModerator(address _moderator) public onlyOwner {
        _grantRole(MODERATOR_ROLE, _moderator);
    }

    function createCampaign(
        address _owner,
        uint256 _target,
        uint256 _startAt,
        uint256 _endAt,
        string memory _metadata
    ) public returns (uint256) {
        require(
            _startAt >= block.timestamp,
            "Start Time Should be Greater than or Equal to Current Time"
        );
        require(_endAt > block.timestamp, "End time is less than Start Date");
        Campaign storage campaign = campaigns[campaignCount];
        campaign.owner = _owner;
        campaign.target = _target;
        campaign.startAt = _startAt;
        campaign.endAt = _endAt;
        campaign.metadata = _metadata;
        campaign.amountCollected = 0;
        campaign.collected = false;

        campaignCount++;
        emit CreateCampaign(_owner, _target, _startAt, _endAt);
        return campaignCount - 1;
    }

    function editCampaignMetadata(uint256 _id, string memory _metadata) public {
        Campaign storage campaign = campaigns[_id];
        require(campaign.owner != address(0), "Campaign does not exist");
        require(campaign.owner == msg.sender, "Only Campaign Owner can edit");
        campaign.metadata = _metadata;
    }

    function deleteCampaign(uint256 _id) public onlyOwner {
        require(
            hasRole(MODERATOR_ROLE, msg.sender),
            "Only Moderators can delete"
        );
        delete campaigns[_id];
    }

    function donateToCampaign(uint256 _id, string memory _nft) public payable {
        uint256 amount = msg.value;
        require(msg.value > 0, "Amount must be greater than 0");
        Campaign storage campaign = campaigns[_id];
        require(
            campaign.startAt < block.timestamp,
            "Campaign has not Started yet"
        );
        require(
            amount <= (campaign.target - campaign.amountCollected),
            "Amount must be less than the remaining target"
        );
        require(campaign.owner != address(0), "Campaign does not exist");
        require(campaign.endAt >= block.timestamp, "Campaign has ended");
        campaign.donators.push(msg.sender);
        campaign.donations.push(amount);
        campaign.amountCollected = campaign.amountCollected + amount;
        nft.safeMint(msg.sender, _nft);
        emit DonateToCampaign(msg.sender, amount, _id);
    }

    function withdraw(uint256 _id) public {
        Campaign storage campaign = campaigns[_id];
        require(campaign.owner != address(0), "Campaign does not exist");
        require(
            campaign.owner == msg.sender,
            "Only Campaign Owner can withdraw"
        );
        require(block.timestamp > campaign.endAt, "Campaign has not ended");
        require(!campaign.collected, "Already Withdrawn");

        // withdraw
        uint256 amount = campaign.amountCollected;
        require(amount > 0, "Collected Amount should be greater than 0");
        (bool sent, ) = payable(campaign.owner).call{value: amount}("");

        if (sent) {
            campaign.amountCollected = campaign.amountCollected + amount;
            delete campaigns[_id];
            emit Withdraw(_id, amount);
        }
    }

    function getDonators(
        uint256 _id
    ) public view returns (address[] memory, uint256[] memory) {
        return (campaigns[_id].donators, campaigns[_id].donations);
    }

    function getCampaigns() public view returns (Campaign[] memory) {
        Campaign[] memory allCampaigns = new Campaign[](campaignCount);
        for (uint256 i = 0; i < campaignCount; i++) {
            Campaign storage item = campaigns[i];
            allCampaigns[i] = item;
        }
        return allCampaigns;
    }
}
