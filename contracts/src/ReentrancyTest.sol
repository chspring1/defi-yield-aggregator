// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ReentrancyTest
 * @dev 演示重入攻击和防护的对比
 */
contract ReentrancyTest is ReentrancyGuard {
    mapping(address => uint256) public balances;
    uint256 public totalWithdrawn;
    
    event WithdrawAttempt(address user, uint256 amount, bool success);
    event ReentrancyBlocked(address attacker);
    
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }
    
    /**
     * @dev 有防护的取款函数
     */
    function safeWithdraw(uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        // 记录尝试
        emit WithdrawAttempt(msg.sender, amount, true);
        
        // 外部调用（可能触发重入）
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        // 更新状态
        balances[msg.sender] -= amount;
        totalWithdrawn += amount;
    }
    
    /**
     * @dev 没有防护的取款函数（用于对比测试）
     */
    function vulnerableWithdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        emit WithdrawAttempt(msg.sender, amount, true);
        
        // 外部调用（容易被重入攻击）
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        // 状态更新（可能被跳过）
        balances[msg.sender] -= amount;
        totalWithdrawn += amount;
    }
    
    /**
     * @dev 检查当前是否在重入保护中
     */
    function isInReentrantCall() external view returns (bool) {
        return _reentrancyGuardEntered();
    }
    
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @title ReentrancyAttacker
 * @dev 模拟重入攻击的恶意合约
 */
contract ReentrancyAttacker {
    ReentrancyTest public target;
    uint256 public attackAmount;
    uint256 public attackCount;
    uint256 public maxAttacks = 3;
    
    event AttackAttempt(uint256 count, bool success, string reason);
    
    constructor(ReentrancyTest _target) {
        target = _target;
    }
    
    function deposit() external payable {
        target.deposit{value: msg.value}();
    }
    
    /**
     * @dev 攻击安全的函数（会被阻止）
     */
    function attackSafe(uint256 amount) external {
        attackAmount = amount;
        attackCount = 0;
        target.safeWithdraw(amount);
    }
    
    /**
     * @dev 攻击脆弱的函数（会成功）
     */
    function attackVulnerable(uint256 amount) external {
        attackAmount = amount;
        attackCount = 0;
        target.vulnerableWithdraw(amount);
    }
    
    /**
     * @dev 接收ETH时触发重入攻击
     */
    receive() external payable {
        attackCount++;
        emit AttackAttempt(attackCount, false, "Attempting reentrancy");
        
        if (attackCount < maxAttacks && target.getBalance() >= attackAmount) {
            try target.safeWithdraw(attackAmount) {
                emit AttackAttempt(attackCount, true, "Safe attack succeeded!");
            } catch Error(string memory reason) {
                emit AttackAttempt(attackCount, false, reason);
            } catch {
                emit AttackAttempt(attackCount, false, "Reentrancy blocked by guard");
            }
        }
    }
}