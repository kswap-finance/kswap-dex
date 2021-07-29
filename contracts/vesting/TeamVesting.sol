// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

contract TeamVesting is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _whitelist;

    uint256 public totalWeight;
    uint256 public totalAmount;
    uint256 public historyAmount;
    uint256 public startTime;
    address public token;
    uint256 public constant PERIOD = 1 days;
    uint256 public constant CYCLE_TIMES = 365 * 3;

    struct UserInfo {
        uint256 weight;
        uint256 historyAmount;
    }

    struct UserView {
        uint256 historyAmount;
        uint256 pendingAmount;
        uint256 totalAmount;
    }

    mapping(address => UserInfo) public users;

    event WithDraw(address to, uint256 amount);

    constructor(address _token, uint256 _totalAmount) public {
        startTime = block.timestamp;
        token = _token;
        totalAmount = _totalAmount;
    }

    function addUser(address _account, uint256 _weight) public onlyOwner {
        require(_weight > 0, "Timelock: weight is 0");
        addWhitelist(_account);
        users[_account].weight = _weight;
        totalWeight = totalWeight.add(_weight);
    }

    function setUserWeight(address _account, uint256 _weight) public onlyOwner {
        uint256 formerWeight = users[_account].weight;
        users[_account].weight = _weight;
        totalWeight = totalWeight.add(_weight).sub(formerWeight);
    }

    function getUserInfo(address _account) public view returns (UserView memory) {
        uint256 pendingAmount = getPendingReward(_account);
        uint256 userHistoryAmount = users[_account].historyAmount;
        uint256 userTotalAmount = users[_account].weight.mul(totalAmount).div(totalWeight);
        return UserView({historyAmount: userHistoryAmount, pendingAmount: pendingAmount, totalAmount: userTotalAmount});
    }

    function getCurrentCycle() public view returns (uint256 cycle) {
        uint256 pCycle = (block.timestamp.sub(startTime)).div(PERIOD);
        cycle = pCycle >= CYCLE_TIMES ? CYCLE_TIMES : pCycle;
    }

    function getPendingReward(address _account) public view returns (uint256) {
        if (!isWhitelist(_account)) return 0;

        uint256 cycle = getCurrentCycle();
        uint256 userReward = users[msg.sender].weight.mul(totalAmount).mul(cycle).div(CYCLE_TIMES).div(totalWeight);
        return userReward.sub(users[msg.sender].historyAmount);
    }

    function withdraw() external {
        require(isWhitelist(msg.sender), "TimeLock: Not in the whitelist");

        uint256 reward = getPendingReward(msg.sender);
        require(reward > 0, "TimeLock: no reward");
        IERC20(token).safeTransfer(msg.sender, reward);
        historyAmount = historyAmount.add(reward);
        users[msg.sender].historyAmount = users[msg.sender].historyAmount.add(reward);
        emit WithDraw(msg.sender, reward);
    }

    function addWhitelist(address _account) public onlyOwner returns (bool) {
        require(_account != address(0), "TimeLock: address is zero");
        return EnumerableSet.add(_whitelist, _account);
    }

    function delWhitelist(address _account) public onlyOwner returns (bool) {
        require(_account != address(0), "TimeLock: address is zero");
        return EnumerableSet.remove(_whitelist, _account);
    }

    function getWhitelistLength() public view returns (uint256) {
        return EnumerableSet.length(_whitelist);
    }

    function isWhitelist(address _account) public view returns (bool) {
        return EnumerableSet.contains(_whitelist, _account);
    }

    function getWhitelist(uint256 _index) public view returns (address) {
        require(_index <= getWhitelistLength() - 1, "TimeLock: index out of bounds");
        return EnumerableSet.at(_whitelist, _index);
    }
}
