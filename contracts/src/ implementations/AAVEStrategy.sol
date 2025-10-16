// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../base/BaseStrategy.sol";
import "../interfaces/IStrategy.sol";

// AAVE V3 接口  这里定义了aave接口的必要部分
interface ILendingPool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function getReserveData(address asset) external view returns (uint256 availableLiquidity, uint256 totalStableDebt, uint256 totalVariableDebt, uint256 liquidityRate, uint256 variableBorrowRate, uint256 stableBorrowRate, uint256 averageStableBorrowRate, uint256 liquidityIndex, uint256 variableBorrowIndex, uint40 lastUpdateTimestamp);
}
// AAVE aToken 接口  这里定义了aToken接口的必要部分
interface IAToken {
    function balanceOf(address user) external view returns (uint256);
    function scaledBalanceOf(address user) external view returns (uint256);
    function principalBalanceOf(address user) external view returns (uint256);
}

/**
 * @title AAVEStrategy
 * @dev AAVE V3 借贷市场收益策略
 * 将资产存入AAVE获取借贷利息收益
 */
contract AAVEStrategy is BaseStrategy {
    // ============ AAVE 配置 ============
    address public constant AAVE_LENDING_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2; // Ethereum Mainnet
    address public aToken;
    uint16 public constant REFERRAL_CODE = 0; // AAVE 推荐码
    
    // ============ 策略特定状态 ============
    uint256 public totalDepositedToAAVE;
    uint256 public totalWithdrawnFromAAVE;
    uint256 public lastCompoundTimestamp;
    uint256 public compoundThreshold = 0.1 ether; // 最小复投阈值
    
    // ============ 事件 ============
    event AAVEDeposited(uint256 amount);
    event AAVEWithdrawn(uint256 amount);
    event CompoundThresholdUpdated(uint256 newThreshold);

    // ============ 构造函数 ============
    constructor(
        address _vault,
        uint256 _maxInvestmentRatio,
        uint256 _harvestInterval,
        uint8 _riskScore,
        address _admin,
        address _aToken
    ) BaseStrategy(_vault, _maxInvestmentRatio, _harvestInterval, _riskScore, _admin) {
        if (_aToken == address(0)) revert InvalidConfiguration();
        aToken = _aToken;
        
        // 授权AAVE Lending Pool使用代币
        _safeApprove(address(want), AAVE_LENDING_POOL, type(uint256).max);
    }
    
    /**
     * @dev 初始化函数（供工厂调用）
     */
    function initialize(
        address _vault,
        uint256 _maxInvestmentRatio,
        uint256 _harvestInterval,
        uint8 _riskScore,
        address _admin
    ) external {
        // 基础初始化逻辑
        // 注意：实际实现可能需要不同的初始化逻辑
    }

    // ============ 核心策略逻辑实现 ============
    /// @dev 投资实现 - 将可用资产存入AAVE
    function _invest() internal override {
        uint256 balance = want.balanceOf(address(this));
        if (balance == 0) return;
        
        // 存入AAVE
        ILendingPool(AAVE_LENDING_POOL).deposit(
            address(want),
            balance,
            address(this),
            REFERRAL_CODE
        );
        
        totalDepositedToAAVE += balance;
        lastCompoundTimestamp = block.timestamp;
        
        emit AAVEDeposited(balance);
        emit Invested(balance);
    }
    /// @dev 撤资实现 - 从AAVE提取指定金额
    /// @param amount 提取金额
    /// @return 实际提取金额
    function _withdraw(uint256 amount) internal override returns (uint256) {
        if (amount == 0) return 0;
        
        uint256 balanceBefore = want.balanceOf(address(this));
        
        // 从AAVE提取
        ILendingPool(AAVE_LENDING_POOL).withdraw(address(want), amount, address(this));
        
        uint256 balanceAfter = want.balanceOf(address(this));
        uint256 withdrawn = balanceAfter - balanceBefore;
        
        if (withdrawn > 0) {
            totalWithdrawnFromAAVE += withdrawn;
            emit AAVEWithdrawn(withdrawn);
            emit Divested(withdrawn);
        }
        
        return withdrawn;
    }
    /// @dev 收获实现 - 计算收益并复投
    /// @return 收益金额
    function _harvest() internal override returns (uint256) {
        // 对于AAVE，收益会自动累积到aToken余额中
        // 我们通过比较aToken余额和初始存款来计算收益
        uint256 currentBalance = _estimatedTotalAssets();
        uint256 principal = totalDepositedToAAVE - totalWithdrawnFromAAVE;
        
        if (currentBalance <= principal) {
            return 0; // 没有收益或亏损
        }
        
        uint256 profit = currentBalance - principal;
        
        // 如果收益达到阈值，自动复投
        if (profit >= compoundThreshold) {
            _compoundRewards(profit);
        }
        
        return profit;
    }
    /// @dev 估算总资产 - 包括在AAVE中的资产
    /// @return 估算的总资产价值
    function _estimatedTotalAssets() internal view override returns (uint256) {
        // aToken余额就是我们在AAVE中的总资产（本金+收益）
        return IAToken(aToken).balanceOf(address(this));
    }
    /// @dev 紧急退出实现 - 提取所有资金从AAVE
    function _emergencyExit() internal override {
        // 从AAVE提取所有资金
        uint256 aTokenBalance = IAToken(aToken).balanceOf(address(this));
        if (aTokenBalance > 0) {
            ILendingPool(AAVE_LENDING_POOL).withdraw(address(want), type(uint256).max, address(this));
        }
    }

    // ============ 收益复投逻辑 ============
    /// @dev 复投收益 - 将收益重新存入AAVE
    /// @param rewards 收益金额
    function _compoundRewards(uint256 rewards) internal {
        if (rewards == 0) return;
        
        // 将收益重新存入AAVE
        ILendingPool(AAVE_LENDING_POOL).deposit(
            address(want),
            rewards,
            address(this),
            REFERRAL_CODE
        );
        
        totalDepositedToAAVE += rewards;
        lastCompoundTimestamp = block.timestamp;
    }
    
    /**
     * @dev 手动触发复投
     */
    function manualCompound() external onlyKeeper {
        uint256 profit = _estimatePendingRewards();
        if (profit > 0) {
            _compoundRewards(profit);
        }
    }

    // ============ 视图函数扩展 ============
    /// @dev 估算待收获的收益
    /// @return 估算的收益金额
    function _estimatePendingRewards() internal view override returns (uint256) {
        uint256 currentBalance = _estimatedTotalAssets();
        uint256 principal = totalDepositedToAAVE - totalWithdrawnFromAAVE;
        
        if (currentBalance > principal) {
            return currentBalance - principal;
        }
        return 0;
    }
    
    /**
     * @dev 获取AAVE市场数据
     * @return liquidityRate 当前流动性利率
     * @return availableLiquidity 当前可用流动性
     * @return totalDeposits 在AAVE中的总存款
     * @return utilizationRate 当前利用率   
     */
    function getAAVEMarketData() external view returns (
        uint256 liquidityRate,
        uint256 availableLiquidity,
        uint256 totalDeposits,
        uint256 utilizationRate
    ) {
        (uint256 availableLiq,,,,uint256 liqRate,,,,) = ILendingPool(AAVE_LENDING_POOL).getReserveData(address(want));
        
        liquidityRate = liqRate;
        availableLiquidity = availableLiq;
        totalDeposits = _estimatedTotalAssets();
        
        // 计算利用率（简化）
        utilizationRate = availableLiquidity > 0 ? 
            (totalDeposits * 1e18) / (availableLiquidity + totalDeposits) : 0;
    }
    
    /**
     * @dev 获取策略详细统计
        * @return aaveBalance 在AAVE中的资产余额
        * @return walletBalance 策略钱包中的资产余额
        * @return pendingRewards 待收获的收益
        * @return currentAPY 当前年化收益率
        * @return utilization 当前利用率（以10000为基数，10000=100%）
     */
    function getStrategyDetails() external view returns (
        uint256 aaveBalance,
        uint256 walletBalance,
        uint256 pendingRewards,
        uint256 currentAPY,
        uint256 utilization
    ) {
        aaveBalance = _estimatedTotalAssets();
        walletBalance = want.balanceOf(address(this));
        pendingRewards = _estimatePendingRewards();
        currentAPY = _calculateCurrentAPY();
        utilization = totalDepositedToAAVE > 0 ? 
            (aaveBalance * 10000) / totalDepositedToAAVE : 0;
    }
    /**
    @dev 计算当前APY - 基于AAVE的流动性利率
    @return 当前APY (精度1e18)
     */
    function _calculateCurrentAPY() internal view returns (uint256) {
        (, , , uint256 liquidityRate, , , , , ,) = ILendingPool(AAVE_LENDING_POOL).getReserveData(address(want));
        
        // AAVE的利率是RAY单位（1e27），转换为APY（1e18）
        // 简化计算: APY = (1 + liquidityRate/1e27)^365 - 1
        // 这里返回原始的liquidityRate，前端可以精确计算
        return liquidityRate;
    }
    /// @dev 获取当前APY
    /// @return 当前APY (精度1e18)
    function getAPY() external view override returns (uint256) {
        return _calculateCurrentAPY();
    }

    // ============ 管理员功能扩展 ============
    
    /**
     * @dev 设置复投阈值
     */
    function setCompoundThreshold(uint256 newThreshold) external onlyAdmin {
        compoundThreshold = newThreshold;
        emit CompoundThresholdUpdated(newThreshold);
    }
    
    /**
     * @dev 更新aToken地址（仅用于紧急情况）
     */
    function setAToken(address newAToken) external onlyAdmin {
        if (newAToken == address(0)) revert InvalidConfiguration();
        aToken = newAToken;
    }
    
    /**
     * @dev 强制收获（忽略时间间隔）
     */
    function forceHarvest() external onlyAdmin returns (uint256) {
        uint256 profit = _estimatePendingRewards();
        if (profit > 0) {
            // 直接报告收益给资金库
            IVault(vault).reportProfit(profit);
            totalEarnings += profit;
            lastHarvestTimestamp = block.timestamp;
            emit Harvested(profit, block.timestamp);
        }
        return profit;
    }

    // ============ 风险管理功能 ============
    
    /**
     * @dev 检查AAVE池健康状态
     */
    function checkPoolHealth() external view returns (bool isHealthy, string memory message) {
        uint256 currentBalance = _estimatedTotalAssets();
        uint256 principal = totalDepositedToAAVE - totalWithdrawnFromAAVE;
        
        if (currentBalance < principal * 99 / 100) { // 允许1%的波动
            return (false, "Potential loss detected");
        }
        
        // 检查AAVE池流动性
        (uint256 availableLiquidity, , , , , , , , ,) = ILendingPool(AAVE_LENDING_POOL).getReserveData(address(want));
        if (availableLiquidity < currentBalance) {
            return (false, "Insufficient pool liquidity");
        }
        
        return (true, "Pool is healthy");
    }
    
    /**
     * @dev 获取风险指标
     */
    function getRiskMetrics() external view returns (
        uint256 collateralFactor,
        uint256 liquidationThreshold,
        uint256 healthFactor
    ) {
        // 这里可以添加更复杂的风险计算
        // 目前返回基础值
        collateralFactor = 7500; // 75% 假设值
        liquidationThreshold = 8000; // 80% 假设值
        healthFactor = 20000; // 2.0 健康因子
    }

    // ============ 重写基础函数 ============
    
    function name() external pure override returns (string memory) {
        return "AAVE Lending Strategy";
    }
    
    function version() external pure override returns (string memory) {
        return "1.0.0";
    }
    
    function supportedChains() external pure override returns (uint256[] memory) {
        uint256[] memory chains = new uint256[](4);
        chains[0] = 1;  // Ethereum Mainnet
        chains[1] = 137; // Polygon
        chains[2] = 42161; // Arbitrum
        chains[3] = 10;  // Optimism
        return chains;
    }
    
    // ============ 工具函数 ============
    
    /**
     * @dev 估算Gas成本
     */
    function estimateGasCost() external view returns (uint256 depositGas, uint256 withdrawGas, uint256 harvestGas) {
        // 估算值，实际可能有所不同
        depositGas = 150000;
        withdrawGas = 120000;
        harvestGas = 80000;
    }

    // ============ 紧急恢复功能 ============
    
    /**
     * @dev 恢复意外发送的aToken
     */
    function recoverAToken(uint256 amount) external onlyAdmin {
        IAToken(aToken).transfer(msg.sender, amount);
    }
    
    /**
     * @dev 重置授权（紧急情况）
     */
    function resetApproval() external onlyAdmin {
        // 重置为0然后重新授权
        _safeApprove(address(want), AAVE_LENDING_POOL, 0);
        _safeApprove(address(want), AAVE_LENDING_POOL, type(uint256).max);
    }
}