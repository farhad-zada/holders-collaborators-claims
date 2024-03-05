// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// this is the holders adopted version of the claims contract
contract Claims is Ownable(msg.sender) {
    using SafeERC20 for IERC20;

    error LengthMismatch();
    error VestingNotStarted();
    error ReentrancyAttack();
    error NotAdmin();
    error InvalidInput();
    error NegativeAmount();
    error NotEnoughContractBalance();

    IERC20 public token;
    string public label;

    modifier vestingScheduleExists() {
        if (vestingSchedule.start > 0) {
            _;
        } else {
            revert VestingNotStarted();
        }
    }

    modifier nonReentrant() {
        if (_nonReentrant[msg.sender] == true) revert ReentrancyAttack();
        _nonReentrant[msg.sender] = true;
        _;
        _nonReentrant[msg.sender] = false;
    }

    modifier admin() {
        // solhint-disable-next-line custom-errors
        require(admins[msg.sender], "Claims: not admin");
        _;
    }

    modifier vestingScheduleCorrect(
        uint256 _start,
        uint256 _rounds,
        uint256 _interval
    ) {
        if (!(_rounds > 0 && _interval > 0 && _start + _rounds * _interval > block.timestamp)) revert InvalidInput();
        _;
    }

    mapping(address => uint256) public allocations;
    mapping(address => uint256) public claimed;
    mapping(address => bool) public _nonReentrant;
    mapping(address => bool) public admins;
    uint256 public totalVestedAmount;
    uint256 public totalClaimedAmount;

    struct VestingSchedule {
        uint256 start;
        uint256 rounds;
        uint256 interval;
    }

    struct Allocated {
        address who;
        uint256 amount;
    }

    mapping(address => bool) public addressExists;
    mapping(address => uint256) public addressIndices;

    Allocated[] public allocated;
    VestingSchedule public vestingSchedule;

    event Claim(address claimer, uint256 amount);
    event Withdraw(address owner, uint256 amount);
    event Allocate(address to, uint256 amount);

    constructor(
        address _token,
        string memory _label,
        uint256 _start,
        uint256 _rounds,
        uint256 _interval,
        address owner
    ) vestingScheduleCorrect(_start, _rounds, _interval) {
        transferOwnership(owner);
        token = IERC20(_token);
        label = _label;
        admins[msg.sender] = true;
        vestingSchedule = VestingSchedule(_start, _rounds, _interval);
    }

    /*
State modifier fonctions
*/

    function setAdmin(address _admin, bool _status) public onlyOwner {
        admins[_admin] = _status;
    }

    function updateToken(address _token) public admin {
        token = IERC20(_token);
    }

    function setVestingSchedule(
        uint256 _start,
        uint256 _rounds,
        uint256 _interval
    ) public admin vestingScheduleCorrect(_start, _rounds, _interval) {
        vestingSchedule = VestingSchedule(_start, _rounds, _interval);
    }

    function setAllocations(address[] calldata _beneficiaries, uint256[] calldata amounts, bool add) public admin {
        if (_beneficiaries.length != amounts.length) revert LengthMismatch();
        for (uint32 i; i < _beneficiaries.length; i++) {
            /* 
            do we need to emit an event for each allocation? 
            */
            emit Allocate(_beneficiaries[i], amounts[i]);

            if (!addressExists[_beneficiaries[i]]) {
                allocated.push(Allocated(_beneficiaries[i], amounts[i]));
                addressIndices[_beneficiaries[i]] = allocated.length - 1;
                addressExists[_beneficiaries[i]] = true;
                totalVestedAmount += amounts[i];
                allocations[_beneficiaries[i]] = add ? amounts[i] + allocations[_beneficiaries[i]] : amounts[i];
                continue;
            } else {
                totalVestedAmount -= allocations[_beneficiaries[i]];
                totalVestedAmount += amounts[i];
                allocations[_beneficiaries[i]] = amounts[i];
                allocated[addressIndices[_beneficiaries[i]]].amount = amounts[i];
            }
        }
    }

    function claim() public nonReentrant vestingScheduleExists {
        int256 amount = getClaimable();
        // solhint-disable-next-line custom-errors
        require(amount > 0, "Negative amount");
        uint256 _amount = uint256(amount);
        emit Claim(msg.sender, _amount);
        // solhint-disable-next-line custom-errors
        require(_amount < token.balanceOf(address(this)), "Not enough contract balance.");
        claimed[msg.sender] += _amount;
        totalClaimedAmount += _amount;
        token.transfer(msg.sender, _amount);
    }

    function setLabel(string memory newLabel) public admin {
        label = newLabel;
    }

    function transferToken(IERC20 _token, address to, uint256 amount) public admin {
        IERC20 tokken = _token;
        tokken.transfer(to, amount);
    }

    /*
State read functions 
*/

    function getAdmin(address account) public view returns (bool) {
        return admins[account];
    }

    function getLeftout() public view returns (int256) {
        return int256(totalVestedAmount) - int256(totalClaimedAmount);
    }

    function allAllocations() public view returns (Allocated[] memory) {
        return allocated;
    }

    function totalVested() public view returns (uint256) {
        return totalVestedAmount;
    }

    function singleAllocation(address who) public view returns (uint256) {
        return allocations[who];
    }

    function totalClaimed() public view returns (uint256) {
        return totalClaimedAmount;
    }

    function singleClaimed(address who) public view returns (uint256) {
        return claimed[who];
    }

    function getAllocation() public view returns (uint256) {
        return allocations[msg.sender];
    }

    function getClaimed() public view returns (uint256) {
        return claimed[msg.sender];
    }

    /*
    Returns how much of allocation have been unlocked till the given moment. 
    This includes the amount alreadhy claimed and the amount is awailable to claim
    */
    function getUnlocked() public view vestingScheduleExists returns (uint256) {
        if (!isVestingScheduleStarted() || allocations[msg.sender] == 0) {
            return 0;
        }
        if (getEndTime() < block.timestamp) {
            return allocations[msg.sender];
        }
        uint256 _round;
        for (uint256 tmp = vestingSchedule.start; tmp < block.timestamp; tmp += vestingSchedule.interval) {
            _round += 1;
        }
        uint256 unlocked = (allocations[msg.sender] / vestingSchedule.rounds) * _round;

        return unlocked;
    }

    /*
    Retunrs how much can the message sender claim at that given moment of interaction 
    */
    function getClaimable() public view vestingScheduleExists returns (int256) {
        return (int256(getUnlocked()) - int256(claimed[msg.sender]));
    }

    /* 
    If the start time has already been passed, a vesting pool has started 
    */
    function isVestingScheduleStarted() public view returns (bool) {
        if (vestingSchedule.start > 0 && vestingSchedule.start < block.timestamp) {
            return true;
        }

        return false;
    }

    /* 
    If the start time has already been passed and end time not still arrived, a vesting pool is active 
    */
    function isVestingScheduleActive() public view returns (bool) {
        if (
            vestingSchedule.start > 0 &&
            vestingSchedule.start < block.timestamp &&
            (vestingSchedule.start + vestingSchedule.interval * vestingSchedule.rounds) > block.timestamp
        ) {
            return true;
        }

        return false;
    }

    /*
    Returns the time left to the schedule end
    */
    function getTimeLeft() public view returns (uint256) {
        // solhint-disable-next-line custom-errors
        require(isVestingScheduleActive(), "No vesting schedule esists.");
        return vestingSchedule.start + vestingSchedule.rounds * vestingSchedule.interval - block.timestamp;
    }

    /*
    Returns the start time of the schedule
    */
    function getStartTime() public view returns (uint256) {
        return vestingSchedule.start;
    }

    /*
    Returns the ending time of schedule
    */
    function getEndTime() public view returns (uint256) {
        return vestingSchedule.interval * vestingSchedule.rounds + getStartTime();
    }

    /*
    Returns the interval in seconds => interval is the gap period between unlocking 
    */
    function getIntervalInSeconds() public view returns (uint256) {
        return vestingSchedule.interval;
    }
}
