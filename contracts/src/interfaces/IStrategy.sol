// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// 策略标准化 - 确保所有策略合约有统一的接口

// 可插拔架构 - 支持动态升级和替换策略

// 职责分离 - 资金库管理存款/取款，策略负责收益生成

// 安全隔离 - 策略逻辑与资金库核心逻辑分离
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IStrategy
 * @dev MultiChain Yield Aggregator 策略标准接口
 * 定义所有收益策略合约必须实现的函数和事件
 */
interface IStrategy {
    
    // ============================================
    //                  事件定义
    // ============================================
    
    /**
     * @dev 策略投资事件
     * @param amount 投资金额
     */
    event Invested(uint256 amount);
    
    /**
     * @dev 策略撤资事件  
     * @param amount 撤资金额
     */
    event Divested(uint256 amount);
    
    /**
     * @dev 收益收获事件
     * @param profit 收益金额
     * @param timestamp 收获时间
     */
    event Harvested(uint256 profit, uint256 timestamp);
    
    /**
     * @dev 策略紧急停止事件
     * @param caller 调用者
     */
    event EmergencyExit(address indexed caller);
    
    /**
     * @dev 策略迁移事件
     * @param newStrategy 新策略地址
     */
    event StrategyMigrated(address indexed newStrategy);

    // ============================================
    //                  错误定义
    // ============================================
    
    error OnlyVault();
    error OnlyAdmin();
    error OnlyKeeper();
    error StrategyNotActive();
    error InsufficientLiquidity();
    error InvestmentFailed();
    error WithdrawalFailed();
    error HarvestFailed();
    error MaxLossExceeded();

    // ============================================
    //                  核心功能
    // ============================================
    
    /**
     * @dev 获取关联的资金库地址
     * @return 资金库合约地址
     */
    function vault() external view returns (address);
    
    /**
     * @dev 获取策略管理的资产地址
     * @return 资产合约地址
     */
    function want() external view returns (IERC20);
    
    /**
     * @dev 投资函数 - 将资金投入收益策略
     */
    function invest() external;
    
    /**
     * @dev 撤资函数 - 从策略中提取资金
     * @param amount 提取金额
     * @return 实际提取金额
     */
    function withdraw(uint256 amount) external returns (uint256);
    
    /**
     * @dev 紧急撤资 - 提取所有资金（紧急情况）
     * @return 提取的总金额
     */
    function emergencyExit() external returns (uint256);
    
    /**
     * @dev 收获收益 - 收集策略产生的收益
     * @return 收益金额
     */
    function harvest() external returns (uint256);

    // ============================================
    //                  状态查询
    // ============================================
    
    /**
     * @dev 估算策略管理的总资产
     * @return 总资产价值
     */
    function estimatedTotalAssets() external view returns (uint256);
    
    /**
     * @dev 获取策略是否活跃
     * @return 是否活跃
     */
    function isActive() external view returns (bool);
    
    /**
     * @dev 获取策略名称
     * @return 策略名称
     */
    function name() external view returns (string memory);
    
    /**
     * @dev 获取策略版本
     * @return 版本字符串
     */
    function version() external view returns (string memory);

    // ============================================
    //                  风险管理
    // ============================================
    
    /**
     * @dev 获取策略风险评分 (1-10, 1=最低风险)
     * @return 风险评分
     */
    function riskScore() external view returns (uint8);
    
    /**
     * @dev 检查策略是否处于紧急状态
     * @return 是否紧急状态
     */
    function inEmergency() external view returns (bool);
    
    /**
     * @dev 获取最大单次投资比例 (精度1e18)
     * @return 最大投资比例
     */
    function maxInvestmentRatio() external view returns (uint256);
    
    /**
     * @dev 获取策略支持的链ID
     * @return 链ID数组
     */
    function supportedChains() external view returns (uint256[] memory);

    // ============================================
    //                  性能指标
    // ============================================
    
    /**
     * @dev 获取策略历史总收益
     * @return 总收益金额
     */
    function totalEarnings() external view returns (uint256);
    
    /**
     * @dev 获取策略APY（年化收益率）
     * @return APY (精度1e18)
     */
    function getAPY() external view returns (uint256);
    
    /**
     * @dev 获取最后收获时间
     * @return 时间戳
     */
    function lastHarvest() external view returns (uint256);
    
    /**
     * @dev 获取收获间隔（秒）
     * @return 收获间隔
     */
    function harvestInterval() external view returns (uint256);

    // ============================================
    //                  管理员功能
    // ============================================
    
    /**
     * @dev 设置Keeper地址（自动执行者）
     * @param keeper Keeper地址
     */
    function setKeeper(address keeper) external;
    
    /**
     * @dev 设置策略参数
     * @param _maxInvestmentRatio 最大投资比例
     * @param _harvestInterval 收获间隔
     */
    function setStrategyParams(
        uint256 _maxInvestmentRatio,
        uint256 _harvestInterval
    ) external;
    
    /**
     * @dev 迁移策略资金到新策略
     * @param newStrategy 新策略地址
     */
    function migrate(address newStrategy) external;

    // ============================================
    //                  多链支持
    // ============================================
    
    /**
     * @dev 跨链资产转移（多链策略）
     * @param chainId 目标链ID
     * @param amount 转移金额
     */
    function crossChainTransfer(uint256 chainId, uint256 amount) external;
    
    /**
     * @dev 获取跨链资产余额
     * @param chainId 链ID
     * @return 资产余额
     */
    function crossChainBalance(uint256 chainId) external view returns (uint256);
}