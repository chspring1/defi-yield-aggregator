/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStrategy.sol";
/*
策略创建 - 部署新的策略合约实例

模板管理 - 管理策略模板和版本

依赖注入 - 为策略配置正确的参数和依赖

注册表功能 - 跟踪所有已部署的策略

升级管理 - 处理策略的版本升级和迁移*

/**
 * @title IStrategyFactory
 * @dev MultiChain Yield Aggregator 策略工厂标准接口
 * 负责策略合约的创建、管理和版本控制
 */
interface IStrategyFactory {
    
    // ============================================
    //                  数据结构
    // ============================================
    
    /**
     * @dev 策略模板信息
     */
    struct StrategyTemplate {
        string name;                    // 策略名称
        string version;                 // 版本号
        address implementation;         // 实现合约地址
        bool isActive;                  // 是否激活
        uint256 createdTime;            // 创建时间
        string description;             // 策略描述
        uint8 riskLevel;               // 风险等级 (1-5)
        string category;                // 策略分类
    }
    
    /**
     * @dev 策略实例信息
     */
    struct StrategyInstance {
        address strategy;               // 策略合约地址
        address vault;                  // 关联的资金库
        address template;               // 模板地址
        uint256 deployedTime;           // 部署时间
        bool isActive;                  // 是否活跃
        uint256 totalDeployed;          // 总部署资产
    }
    
    /**
     * @dev 策略配置参数
     */
    struct StrategyConfig {
        uint256 maxInvestmentRatio;     // 最大投资比例
        uint256 harvestInterval;        // 收获间隔
        uint256 performanceFee;         // 性能费用
        address keeper;                 // 执行者地址
        address treasury;               // 国库地址
        uint256 chainId;                // 目标链ID
    }

    // ============================================
    //                  事件定义
    // ============================================
    
    /**
     * @dev 新模板注册事件
     * @param templateId 模板ID
     * @param implementation 实现地址
     * @param name 策略名称
     * @param version 版本号
     */
    event TemplateRegistered(
        bytes32 indexed templateId,
        address indexed implementation,
        string name,
        string version
    );
    
    /**
     * @dev 策略创建事件
     * @param strategy 策略地址
     * @param vault 资金库地址
     * @param templateId 模板ID
     * @param creator 创建者
     */
    event StrategyCreated(
        address indexed strategy,
        address indexed vault,
        bytes32 indexed templateId,
        address creator
    );
    
    /**
     * @dev 模板状态更新事件
     * @param templateId 模板ID
     * @param isActive 是否激活
     */
    event TemplateStatusUpdated(
        bytes32 indexed templateId,
        bool isActive
    );
    
    /**
     * @dev 策略升级事件
     * @param oldStrategy 旧策略地址
     * @param newStrategy 新策略地址
     * @param vault 资金库地址
     */
    event StrategyUpgraded(
        address indexed oldStrategy,
        address indexed newStrategy,
        address indexed vault
    );

    // ============================================
    //                  错误定义
    // ============================================
    
    error TemplateAlreadyExists();
    error TemplateNotFound();
    error TemplateNotActive();
    error InvalidTemplate();
    error InvalidConfiguration();
    error Unauthorized();
    error StrategyCreationFailed();
    error UpgradeNotAllowed();
    error DuplicateStrategy();

    // ============================================
    //                  模板管理
    // ============================================
    
    /**
     * @dev 注册新的策略模板
     * @param name 策略名称
     * @param version 版本号
     * @param implementation 实现合约地址
     * @param description 策略描述
     * @param riskLevel 风险等级
     * @param category 策略分类
     * @return templateId 模板ID
     */
    function registerTemplate(
        string memory name,
        string memory version,
        address implementation,
        string memory description,
        uint8 riskLevel,
        string memory category
    ) external returns (bytes32 templateId);
    
    /**
     * @dev 更新模板实现地址
     * @param templateId 模板ID
     * @param newImplementation 新实现地址
     */
    function updateTemplateImplementation(
        bytes32 templateId,
        address newImplementation
    ) external;
    
    /**
     * @dev 激活/停用模板
     * @param templateId 模板ID
     * @param isActive 是否激活
     */
    function setTemplateStatus(bytes32 templateId, bool isActive) external;
    
    /**
     * @dev 获取模板信息
     * @param templateId 模板ID
     * @return 模板信息
     */
    function getTemplate(bytes32 templateId) external view returns (StrategyTemplate memory);
    
    /**
     * @dev 获取所有活跃模板
     * @return 活跃模板数组
     */
    function getActiveTemplates() external view returns (bytes32[] memory);
    
    /**
     * @dev 根据分类获取模板
     * @param category 分类名称
     * @return 模板ID数组
     */
    function getTemplatesByCategory(string memory category) external view returns (bytes32[] memory);

    // ============================================
    //                  策略创建
    // ============================================
    
    /**
     * @dev 创建新的策略实例
     * @param templateId 模板ID
     * @param vault 资金库地址
     * @param config 策略配置
     * @return strategy 新策略地址
     */
    function createStrategy(
        bytes32 templateId,
        address vault,
        StrategyConfig memory config
    ) external returns (address strategy);
    
    /**
     * @dev 克隆已存在的策略（用于快速部署）
     * @param templateId 模板ID
     * @param vault 资金库地址
     * @param sourceStrategy 源策略地址
     * @return strategy 新策略地址
     */
    function cloneStrategy(
        bytes32 templateId,
        address vault,
        address sourceStrategy
    ) external returns (address strategy);

    // ============================================
    //                  策略管理
    // ============================================
    
    /**
     * @dev 获取资金库的所有策略
     * @param vault 资金库地址
     * @return 策略地址数组
     */
    function getVaultStrategies(address vault) external view returns (address[] memory);
    
    /**
     * @dev 获取策略实例信息
     * @param strategy 策略地址
     * @return 策略实例信息
     */
    function getStrategyInstance(address strategy) external view returns (StrategyInstance memory);
    
    /**
     * @dev 验证策略是否由本工厂创建
     * @param strategy 策略地址
     * @return 是否有效
     */
    function isValidStrategy(address strategy) external view returns (bool);
    
    /**
     * @dev 获取策略创建者
     * @param strategy 策略地址
     * @return 创建者地址
     */
    function getStrategyCreator(address strategy) external view returns (address);

    // ============================================
    //                  升级管理
    // ============================================
    
    /**
     * @dev 升级策略到新版本
     * @param oldStrategy 旧策略地址
     * @param newTemplateId 新模板ID
     * @param config 新配置
     * @return newStrategy 新策略地址
     */
    function upgradeStrategy(
        address oldStrategy,
        bytes32 newTemplateId,
        StrategyConfig memory config
    ) external returns (address newStrategy);
    
    /**
     * @dev 检查策略是否可以升级
     * @param strategy 策略地址
     * @param newTemplateId 新模板ID
     * @return 是否可以升级
     */
    function canUpgradeStrategy(address strategy, bytes32 newTemplateId) external view returns (bool);
    
    /**
     * @dev 获取策略的推荐升级版本
     * @param strategy 策略地址
     * @return 推荐模板ID
     */
    function getRecommendedUpgrade(address strategy) external view returns (bytes32);

    // ============================================
    //                  统计分析
    // ============================================
    
    /**
     * @dev 获取工厂统计信息
     * @return totalTemplates 总模板数
     * @return totalStrategies 总策略数
     * @return activeStrategies 活跃策略数
     * @return totalTVL 总锁定价值
     */
    function getFactoryStats() external view returns (
        uint256 totalTemplates,
        uint256 totalStrategies,
        uint256 activeStrategies,
        uint256 totalTVL
    );
    
    /**
     * @dev 获取分类统计
     * @return categories 分类数组
     * @return counts 每个分类的策略数量
     */
    function getCategoryStats() external view returns (
        string[] memory categories,
        uint256[] memory counts
    );
    
    /**
     * @dev 获取模板使用统计
     * @param templateId 模板ID
     * @return deploymentCount 部署次数
     * @return totalTVL 总锁定价值
     * @return successRate 成功率
     */
    function getTemplateStats(bytes32 templateId) external view returns (
        uint256 deploymentCount,
        uint256 totalTVL,
        uint256 successRate
    );

    // ============================================
    //                  管理员功能
    // ============================================
    
    /**
     * @dev 设置默认配置参数
     * @param defaultKeeper 默认执行者
     * @param defaultTreasury 默认国库
     * @param defaultPerformanceFee 默认性能费
     */
    function setDefaultConfig(
        address defaultKeeper,
        address defaultTreasury,
        uint256 defaultPerformanceFee
    ) external;
    
    /**
     * @dev 设置创建费用
     * @param creationFee 创建费用
     */
    function setCreationFee(uint256 creationFee) external;
    
    /**
     * @dev 紧急暂停所有策略创建
     * @param paused 是否暂停
     */
    function setFactoryPaused(bool paused) external;
    
    /**
     * @dev 获取工厂状态
     * @return isPaused 是否暂停
     * @return creationFee 创建费用
     * @return admin 管理员地址
     */
    function getFactoryStatus() external view returns (
        bool isPaused,
        uint256 creationFee,
        address admin
    );
}