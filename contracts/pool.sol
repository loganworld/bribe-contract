// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract Pool is Ownable {
    event PoolCreated(uint id, PoolData _pooldata);
    event PoolClosed(uint id);

    struct PoolData {
        string proposalId;
        string name;
        string description;
        string platformType;
        string outcome;
        address rewardCurrency;
        uint rewardAmount;
        address creator;
        bool isClosed;
        uint paybackAmount;
    }

    // pool data
    mapping(uint => PoolData) public poolDatas;
    uint public poolCount;
    // proposal pool created info
    mapping(string => bool) public isCreated;

    // user reward Info
    mapping(address => mapping(uint => uint)) public rewardInfos;

    // admin info
    address public admin;
    uint public fee; // fee*1000000

    modifier onlyAdmin() {
        require(msg.sender == admin, "Invalid admin");
        _;
    }

    constructor(address _admin, uint _fee) {
        admin = _admin;
        require(_fee < 1000000, "Invalide fee");
        fee = _fee;
    }

    function setAdminSetting(address _admin, uint _fee) external onlyOwner {
        admin = _admin;
        require(_fee < 1000000, "Invalide fee");
        fee = _fee;
    }

    function createPool(PoolData memory _pooldata) external {
        require(
            !isCreated[_pooldata.proposalId],
            "pool already created for proposal"
        );
        IERC20(_pooldata.rewardCurrency).transferFrom(
            msg.sender,
            address(this),
            _pooldata.rewardAmount
        );

        IERC20(_pooldata.rewardCurrency).transfer(
            owner(),
            (_pooldata.rewardAmount * fee) / 1000000
        );

        _pooldata.rewardAmount -= (_pooldata.rewardAmount * fee) / 1000000;

        _pooldata.isClosed = false;
        _pooldata.paybackAmount = 0;
        poolDatas[poolCount] = _pooldata;

        emit PoolCreated(poolCount, _pooldata);
        poolCount++;
    }

    function addReward(uint id, uint amount) external {
        require(poolCount > id, "invalid id");
        IERC20(poolDatas[id].rewardCurrency).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        poolDatas[poolCount].rewardAmount += amount;
    }

    function closePool(
        uint id,
        address[] memory voters,
        uint[] memory voteAmounts
    ) external onlyAdmin {
        require(poolCount > id, "invalid id");
        require(voters.length == voteAmounts.length, "Invalid parameter");
        require(poolDatas[id].isClosed == false, "Already created");
        uint totalVoteAmounts = 0;
        for (uint i = 0; i < voteAmounts.length; i++) {
            totalVoteAmounts += voteAmounts[i];
        }

        if (totalVoteAmounts == 0) {
            poolDatas[id].paybackAmount = poolDatas[id].rewardAmount;
            poolDatas[id].isClosed = true;
            emit PoolClosed(id);
            return;
        }

        // get reward amount per vote
        uint rewardPerVote = poolDatas[id].rewardAmount / totalVoteAmounts;

        for (uint i = 0; i < voters.length; i++) {
            rewardInfos[voters[i]][id] = voteAmounts[i] * rewardPerVote;
        }
        poolDatas[id].isClosed = true;

        emit PoolClosed(id);
    }

    function claim(uint id) external {
        uint rewardAmount = rewardInfos[msg.sender][id];
        IERC20(poolDatas[id].rewardCurrency).transfer(msg.sender, rewardAmount);
        rewardInfos[msg.sender][id] = 0;
    }

    function claimPayBack(uint id) external {
        require(msg.sender == poolDatas[id].creator, "Only creator can claim");
        IERC20(poolDatas[id].rewardCurrency).transfer(
            msg.sender,
            poolDatas[id].paybackAmount
        );
        poolDatas[id].paybackAmount = 0;
    }
}
