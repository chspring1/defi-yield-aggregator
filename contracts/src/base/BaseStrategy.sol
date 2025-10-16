// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IStrategy.sol";
import "../interfaces/IVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // IERC20 接口
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; // 安全的 ERC20 操作
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // 重入保护
import "@openzeppelin/contracts/access/AccessControl.sol";  // 角色权限管理
import "@openzeppelin/contracts/utils/math/Math.sol"; // 数学工具库

/**
 * @title BaseStrategy
 * @dev MultiChain Yield Aggregator 所有收益策略的基础抽象合约
 * 提供策略共享的核心逻辑、安全机制和标准接口
 */
abstract contract BaseStrategy is IStrategy, ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    // ============ 常量 ============
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    uint256 public constant MAX_BPS = 10_000; // 100.00%
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    
    // ============ 不可变状态 ============
    address public immutable override vault;
    IERC20 public immutable override want;
    
    // ============ 可变状态 ============
    bool public override isActive = true;
    bool public override inEmergency = false;
    
    // 策略配置
    uint256 public override maxInvestmentRatio;
    uint256 public override harvestInterval;
    uint256 public override lastHarvestTimestamp;
    uint256 public override totalEarnings;
    
    // 风险管理
    uint8 public override riskScore;
    uint256 public minHarvestThreshold;
    uint256 public maxTotalAssets; // 最大管理资产限制
    
    // 统计信息
    uint256 public totalInvested;
    uint256 public totalWithdrawn;
    uint256 public lastInvestmentTimestamp;
    uint256 public performanceFactor; // 用于APY计算的表现因子

    // ============ 事件 ============
    
    /**
     * @dev 策略参数更新事件
     */
    event StrategyParamsUpdated(
        uint256 maxInvestmentRatio,
        uint256 harvestInterval,
        uint256 minHarvestThreshold
    );
    
    /**
     * @dev 风险管理参数更新事件
     */
    event RiskParamsUpdated(
        uint8 riskScore,
        uint256 maxTotalAssets
    );

    // ============ 修饰器 ============
    /// @dev 仅允许资金库调用
    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }
    /// @dev 仅允许管理员调用
    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert OnlyAdmin();
        _;
    }
    /// @dev 仅允许Keeper调用
    modifier onlyKeeper() {
        if (!hasRole(KEEPER_ROLE, msg.sender)) revert OnlyKeeper();
        _;
    }
    /// @dev 策略必须处于活跃状态
    modifier whenActive() {
        if (!isActive) revert StrategyNotActive();
        _;
    }
    /// @dev 策略不能处于紧急状态
    modifier whenNotEmergency() {
        if (inEmergency) revert StrategyNotActive();
        _;
    }
    /// @dev 仅允许资金库或Keeper调用
    modifier onlyVaultOrKeeper() {
        if (msg.sender != vault && !hasRole(KEEPER_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    // ============ 构造函数 ============
    constructor(
        address _vault,
        uint256 _maxInvestmentRatio,
        uint256 _harvestInterval,
        uint8 _riskScore,
        address _admin
    ) {
        if (_vault == address(0)) revert InvalidConfiguration();
        if (_maxInvestmentRatio > MAX_BPS) revert InvalidConfiguration();
        if (_riskScore == 0 || _riskScore > 10) revert InvalidConfiguration();
        
        vault = _vault;
        want = IERC20(IVault(_vault).asset());
        maxInvestmentRatio = _maxInvestmentRatio;
        harvestInterval = _harvestInterval;
        riskScore = _riskScore;
        minHarvestThreshold = 1e6; // 默认最小收获阈值
        maxTotalAssets = type(uint256).max;
        
        _setupRole(ADMIN_ROLE, _admin);
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(KEEPER_ROLE, _admin);
        
        lastHarvestTimestamp = block.timestamp;
    }
    
    // ============ 抽象方法（必须由子类实现） ============
    
    /**
     * @dev 内部投资逻辑 - 将资金投入收益协议
     */
    function _invest() internal virtual;
    
    /**
     * @dev 内部撤资逻辑 - 从收益协议提取资金
     * @param amount 提取金额
     * @return 实际提取金额
     */
    function _withdraw(uint256 amount) internal virtual returns (uint256);
    
    /**
     * @dev 内部收获逻辑 - 收集收益
     * @return 收益金额
     */
    function _harvest() internal virtual returns (uint256);
    
    /**
     * @dev 估算协议中总资产
     * @return 总资产估值
     */
    function _estimatedTotalAssets() internal view virtual returns (uint256);
    
    /**
     * @dev 紧急退出逻辑 - 紧急情况下提取所有资金
     */
    function _emergencyExit() internal virtual;

    // ============ 核心功能实现 ============
    /// @dev 投资函数 - 将闲置资金投入收益策略
    /// 仅在策略活跃且非紧急状态下由资金库或Keeper调用

    function invest() external override whenActive whenNotEmergency onlyVaultOrKeeper {
        if (!_shouldInvest()) return;
        
        uint256 toInvest = _calculateInvestmentAmount();
        if (toInvest == 0) return;
        
        uint256 balanceBefore = want.balanceOf(address(this));
        _invest();
        uint256 balanceAfter = want.balanceOf(address(this));
        
        uint256 invested = balanceBefore - balanceAfter;
        if (invested > 0) {
            totalInvested += invested;
            lastInvestmentTimestamp = block.timestamp;
            emit Invested(invested);
        }
    }
    /// @dev 撤资函数 - 从策略中提取资金
    /// 仅由资金库调用，防止用户直接访问
    /// 使用 nonReentrant 修饰器防止重入攻击
    /// 确保不会过度提取资金
    /// 返回实际提取金额
    function withdraw(uint256 amount) 
        external 
        override 
        onlyVault 
        nonReentrant 
        returns (uint256) 
    {
        if (amount == 0) return 0;
        
        uint256 balanceBefore = want.balanceOf(address(this));
        uint256 withdrawn = _withdraw(amount);
        uint256 balanceAfter = want.balanceOf(address(this));
        
        uint256 actualWithdrawn = balanceAfter - balanceBefore;
        if (actualWithdrawn > 0) {
            // 确保不会过度提取
            actualWithdrawn = Math.min(actualWithdrawn, amount);
            want.safeTransfer(vault, actualWithdrawn);
            totalWithdrawn += actualWithdrawn;
            emit Divested(actualWithdrawn);
        }
        
        return actualWithdrawn;
    }
    /// @dev 收获收益 - 收集策略产生的收益
    /// 仅在策略活跃且非紧急状态下由资金库或Keeper调用
    /// @notice 收获间隔和最小收获阈值检查
    /// @return 返回实际收获金额
    function harvest() 
        external 
        override 
        whenActive 
        nonReentrant 
        onlyVaultOrKeeper 
        returns (uint256) 
    {
        // 检查收获间隔
        if (block.timestamp < lastHarvestTimestamp + harvestInterval) {
            revert HarvestFailed();
        }
        
        // 检查最小收获阈值
        uint256 estimatedProfit = _estimatePendingRewards();
        if (!_checkMinHarvestThreshold(estimatedProfit)) {
            revert HarvestFailed();
        }
        
        uint256 balanceBefore = want.balanceOf(address(this));
        uint256 harvested = _harvest();
        uint256 balanceAfter = want.balanceOf(address(this));
        
        uint256 actualHarvested = balanceAfter - balanceBefore;
        if (actualHarvested > 0) {
            totalEarnings += actualHarvested;
            lastHarvestTimestamp = block.timestamp;
            
            // 更新表现因子（简化版本）
            _updatePerformanceFactor(actualHarvested);
            
            // 报告收益给资金库
            IVault(vault).reportProfit(actualHarvested);
            emit Harvested(actualHarvested, block.timestamp);
        }
        
        return actualHarvested;
    }
    /// @dev 紧急撤资 - 提取所有资金（紧急情况）
    /// 仅由管理员调用，策略变为非活跃状态  
    /// @notice 紧急撤出资金
    /// @return 提取的总金额

    function emergencyExit() 
        external 
        override 
        onlyAdmin 
        nonReentrant 
        returns (uint256) 
    {
        inEmergency = true;
        isActive = false;
        
        // 执行策略特定的紧急退出逻辑
        _emergencyExit();
        
        // 撤资所有资金
        uint256 totalAssets = _estimatedTotalAssets();
        if (totalAssets > 0) {
            _withdraw(totalAssets);
        }
        
        uint256 balance = want.balanceOf(address(this));
        if (balance > 0) {
            want.safeTransfer(vault, balance);
        }
        
        emit EmergencyExit(msg.sender);
        return balance;
    }

    // ============ 视图函数 ============
    /// @dev 估算策略管理的总资产
    /// 包括合约内持有的资产和在收益协议中的资产
    /// 返回总资产价值
    /// @notice 估算策略管理的总资产
    /// @return 返回总资产
    function estimatedTotalAssets() 
        external 
        view 
        override 
        returns (uint256) 
    {
        return want.balanceOf(address(this)) + _estimatedTotalAssets();
    }
    /// @dev 获取策略是否活跃
    function isActive() external view override returns (bool) {
        return isActive && !inEmergency;
    }
    /// @dev 获取策略名称
    function name() external pure virtual override returns (string memory) {
        return "BaseStrategy";
    }
    /// @dev 获取策略版本
    function version() external pure virtual override returns (string memory) {
        return "1.0.0";
    }
    /// @风险评分
    function riskScore() external view override returns (uint8) {
        return riskScore;
    }
    /// @dev 检查策略是否处于紧急状态
    function inEmergency() external view override returns (bool) {
        return inEmergency;
    }
    /// @dev 获取最大投资比例
    function maxInvestmentRatio() external view override returns (uint256) {
        return maxInvestmentRatio;
    }
    /// @dev 年化收益率
    function getAPY() external view virtual override returns (uint256) {
        uint256 totalAssetsValue = estimatedTotalAssets(); //获取收益率
        if (totalAssetsValue == 0) return 0;
        
        // 基于历史收益计算APY
        if (totalEarnings > 0 && block.timestamp > lastHarvestTimestamp) {
            uint256 timeElapsed = block.timestamp - lastHarvestTimestamp;
            uint256 annualizedEarnings = totalEarnings * SECONDS_PER_YEAR / timeElapsed;
            return annualizedEarnings * 1e18 / totalAssetsValue;
        }
        
        return 0;
    }
    /// @dev 获取最后收获时间
    function lastHarvest() external view override returns (uint256) {
        return lastHarvestTimestamp;
    }
    /// @dev 获取收获间隔
    function harvestInterval() external view override returns (uint256) {
        return harvestInterval;
    }
    /// @dev 获取总收益
    function totalEarnings() external view override returns (uint256) {
        return totalEarnings;
    }
    /// @dev 获取策略支持的链ID
    /// 默认只支持以太坊主网 (chainId = 1)
    /// 子类可以覆盖此方法以支持更多链

        function supportedChains() 
        external 
        pure 
        virtual 
        override 
        returns (uint256[] memory) 
    {
        uint256[] memory chains = new uint256[](1);
        chains[0] = 1; // 默认支持以太坊主网
        return chains;
    }
    
    /**
     * @dev 获取策略统计信息
     */
     
    function getStrategyStats() external view returns (
        uint256 currentAssets,
        uint256 totalInvested_,
        uint256 totalWithdrawn_,
        uint256 totalEarnings_,
        uint256 utilizationRate
    ) {
        currentAssets = estimatedTotalAssets();
        totalInvested_ = totalInvested;
        totalWithdrawn_ = totalWithdrawn;
        totalEarnings_ = totalEarnings;
        utilizationRate = currentAssets == 0 ? 0 : 
            (totalInvested - totalWithdrawn) * MAX_BPS / currentAssets;
    }

    // ============ 管理员功能 ============
    /// @dev 设置keeper地址
    function setKeeper(address keeper) external override onlyAdmin {
        if (keeper == address(0)) revert InvalidConfiguration();
        _grantRole(KEEPER_ROLE, keeper);
    }
    /// @dev 设置策略参数
    function setStrategyParams(
        uint256 _maxInvestmentRatio,
        uint256 _harvestInterval
    ) external override onlyAdmin {
        if (_maxInvestmentRatio > MAX_BPS) revert InvalidConfiguration();
        if (_harvestInterval < 3600) revert InvalidConfiguration(); // 最小1小时
        
        maxInvestmentRatio = _maxInvestmentRatio;
        harvestInterval = _harvestInterval;
        
        emit StrategyParamsUpdated(_maxInvestmentRatio, _harvestInterval, minHarvestThreshold);
    }
    /// @dev 迁移到新策略
    /// 仅由管理员调用  
    function migrate(address newStrategy) external override onlyAdmin {
        if (newStrategy == address(0)) revert InvalidConfiguration();
        if (newStrategy == address(this)) revert InvalidConfiguration();
        
        // 撤资所有资金
        uint256 totalAssets = _estimatedTotalAssets();
        if (totalAssets > 0) {
            _withdraw(totalAssets);
        }
        
        // 转移剩余资金到新策略
        uint256 balance = want.balanceOf(address(this));
        if (balance > 0) {
            want.safeTransfer(newStrategy, balance);
        }
        
        isActive = false;
        emit StrategyMigrated(newStrategy);
    }
    /// @dev 设置最小收获阈值
    function setMinHarvestThreshold(uint256 threshold) external onlyAdmin {
        minHarvestThreshold = threshold;
        emit StrategyParamsUpdated(maxInvestmentRatio, harvestInterval, threshold);
    }
    /// @dev 设置风险评分
    function setRiskScore(uint8 newRiskScore) external onlyAdmin {
        if (newRiskScore == 0 || newRiskScore > 10) revert InvalidConfiguration();
        riskScore = newRiskScore;
        emit RiskParamsUpdated(newRiskScore, maxTotalAssets);
    }
    /// @dev 设置最大管理资产
    function setMaxTotalAssets(uint256 maxAssets) external onlyAdmin {
        maxTotalAssets = maxAssets;
        emit RiskParamsUpdated(riskScore, maxAssets);
    }
    /// @dev 暂停策略
    function pauseStrategy() external onlyAdmin {
        isActive = false;
    }
    /// @dev 恢复策略
    function resumeStrategy() external onlyAdmin {
        isActive = true;
        if (inEmergency) {
            inEmergency = false;
        }
    }

    // ============ 内部工具函数 ============
    /// @dev 决定是否应该进行投资
    function _shouldInvest() internal view returns (bool) {
        uint256 currentAssets = estimatedTotalAssets();
        if (currentAssets >= maxTotalAssets) return false;
        
        uint256 available = want.balanceOf(address(this));
        if (available == 0) return false;
        
        uint256 maxToInvest = currentAssets * maxInvestmentRatio / MAX_BPS;
        return available <= maxToInvest;
    }
    /// @dev 计算应该投资的金额
    function _calculateInvestmentAmount() internal view returns (uint256) {
        uint256 available = want.balanceOf(address(this));
        uint256 currentAssets = estimatedTotalAssets();
        uint256 maxToInvest = currentAssets * maxInvestmentRatio / MAX_BPS;
        
        return Math.min(available, maxToInvest);
    }
    /// @dev 检查是否达到最小收获阈值
    function _checkMinHarvestThreshold(uint256 amount) internal view returns (bool) {
        return amount >= minHarvestThreshold;
    }
    /// @dev 估算待收获的收益
    function _estimatePendingRewards() internal view virtual returns (uint256) {
        // 基础实现返回0，子类应该覆盖这个方法
        return 0;
    }
    /// @dev 更新表现因子（简化版本）
    function _updatePerformanceFactor(uint256 harvested) internal {
        // 简化的表现因子计算
        uint256 totalAssetsValue = estimatedTotalAssets();
        if (totalAssetsValue > 0) {
            uint256 harvestRate = harvested * 1e18 / totalAssetsValue;
            performanceFactor = (performanceFactor * 9 + harvestRate * 1) / 10; // 移动平均
        }
    }
    /// @dev 安全的ERC20操作,防止授权和转账失败

    function _safeApprove(
        address token, 
        address spender, 
        uint256 amount
    ) internal {
        if (IERC20(token).allowance(address(this), spender) < amount) {
            IERC20(token).safeApprove(spender, 0);
            IERC20(token).safeApprove(spender, amount);
        }
    }
    /// @dev 安全的ERC20转账
    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (amount > 0) {
            IERC20(token).safeTransfer(to, amount);
        }
    }
    
    // ============ 跨链功能（基础实现） ============
    /// @dev 跨链转账 - 基础实现，子类可以覆盖
    function crossChainTransfer(uint256 chainId, uint256 amount) 
        external 
        virtual 
        override 
        onlyAdmin 
    {
        // 基础实现，子类可以覆盖实现具体跨链逻辑
        revert("Cross-chain not implemented");
    }
    /// @dev 查询跨链余额 - 基础实现，子类可以覆盖
    function crossChainBalance(uint256 chainId) 
        external 
        view 
        virtual 
        override 
        returns (uint256) 
    {
        // 基础实现，子类可以覆盖
        return 0;
    }
    
    // ============ 接收以太币（如果需要） ============
    
    receive() external payable {}
    
    // ============ 紧急恢复功能 ============
    
    /**
     * @dev 恢复意外发送的代币
     */
    function recoverToken(address token, uint256 amount) external onlyAdmin {
        if (token == address(want)) {
            revert("Cannot recover want token");
        }
        IERC20(token).safeTransfer(msg.sender, amount);
    }
    
    /**
     * @dev 恢复意外发送的以太币
     */
    function recoverETH(uint256 amount) external onlyAdmin {
        payable(msg.sender).transfer(amount);
    }
}