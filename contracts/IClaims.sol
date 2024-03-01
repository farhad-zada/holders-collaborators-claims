// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface ITokenClaims {
    function initialize(address _token, string memory _label) external;

    function setAdmin(address _admin, bool _status) external;

    function updateToken(address _token) external;

    function setVestingSchedule(uint256 _start, uint256 _rounds, uint256 _interval) external;

    function setAllocations(address[] calldata _beneficiaries, uint256[] calldata amounts, bool add) external;

    function claim() external;

    function setLabel(string memory newLabel) external;

    function transferToken(IERC20Upgradeable _token, address to, uint256 amount) external;

    function getAdmin(address account) external view returns (bool);

    function getLeftout() external view returns (int256);

    // function allAllocations() external view returns (Allocated[] memory);

    function totalVested() external view returns (uint256);

    function singleAllocation(address who) external view returns (uint256);

    function totalClaimed() external view returns (uint256);

    function singleClaimed(address who) external view returns (uint256);

    function getAllocation() external view returns (uint256);

    function getClaimed() external view returns (uint256);

    function getUnlocked() external view returns (uint256);

    function getClaimable() external view returns (int256);

    function isVestingScheduleStarted() external view returns (bool);

    function isVestingScheduleActive() external view returns (bool);

    function getTimeLeft() external view returns (uint256);

    function getStartTime() external view returns (uint256);

    function getEndTime() external view returns (uint256);

    function getIntervalInSeconds() external view returns (uint256);
}
