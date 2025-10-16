// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IStrategyFactory.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IVault.sol";
import "../base/BaseStrategy.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";// AccessControl 用于角色管理
import "@openzeppelin/contracts/proxy/Clones.sol";// Clones 用于创建最小代理合约
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";// ReentrancyGuard 用于防止重入攻击
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";// EnumerableSet 用于管理集合
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title StrategyFactory
 * @dev MultiChain Yield Aggregator 策略工厂实现
 * 负责策略合约的创建、管理、版本控制和生命周期管理
 */
contract StrategyFactory is IStrategyFactory, AccessControl, ReentrancyGuard {
    using Clones for address;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TEMPLATE_MANAGER_ROLE = keccak256("TEMPLATE_MANAGER_ROLE");
    
    // ============ 工厂状态 ============
    bool public factoryPaused;
    uint256 public creationFee;
    address public defaultKeeper;
    address public defaultTreasury;
    uint256 public defaultPerformanceFee = 2000; // 20%
    uint256 public maxStrategiesPerVault = 10;
    
    // ============ 模板管理 ============
    mapping(bytes32 => StrategyTemplate) public templates;
    EnumerableSet.Bytes32Set private templateIds;
    mapping(string => bytes32[]) public categoryTemplates;
    mapping(address => bytes32) public implementationToTemplate;
    
    // ============ 实例管理 ============
    mapping(address => StrategyInstance) public strategyInstances;
    mapping(address => EnumerableSet.AddressSet) private vaultStrategies;
    mapping(bytes32 => uint256) public templateDeploymentCount;
    mapping(bytes32 => uint256) public templateTotalTVL;
    mapping(address => address) public strategyToCreator;
    
    // ============ 统计信息 ============
    uint256 public totalStrategiesCreated;
    uint256 public totalStrategiesActive;
    uint256 public factoryTotalTVL;

    // ============ 事件 ============
    event FactoryConfigUpdated(
        address defaultKeeper,
        address defaultTreasury,
        uint256 defaultPerformanceFee,
        uint256 creationFee
    );
    
    event StrategyStatusUpdated(
        address indexed strategy,
        bool isActive
    );

    // ============ 修饰器 ============
    modifier whenNotPaused() {
        if (factoryPaused) revert Unauthorized();
        _;
    }
    
    modifier onlyTemplateManager() {
        if (!hasRole(TEMPLATE_MANAGER_ROLE, msg.sender) && !hasRole(ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    // ============ 构造函数 ============
    constructor(address _admin) {
        _setupRole(ADMIN_ROLE, _admin);
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(TEMPLATE_MANAGER_ROLE, _admin);
        
        creationFee = 0;
        factoryPaused = false;
        defaultKeeper = _admin;
        defaultTreasury = _admin;
    }
    
    // ============ 模板管理 ============
    /// @dev 注册新的策略模板
    /// @param name 策略名称
    /// @param version 版本号   
    /// @param implementation 实现合约地址
    /// @param description 策略描述
    /// @param riskLevel 风险等级（1-10）
    /// @param category 策略分类
    /// @return templateId 生成的模板ID
    
    function registerTemplate(
        string memory name,
        string memory version,
        address implementation,
        string memory description,
        uint8 riskLevel,
        string memory category
    ) external override onlyTemplateManager returns (bytes32 templateId) {
        if (implementation == address(0)) revert InvalidTemplate();
        if (riskLevel == 0 || riskLevel > 10) revert InvalidConfiguration();
        if (bytes(name).length == 0) revert InvalidConfiguration();
        
        templateId = keccak256(abi.encodePacked(name, version, implementation));
        if (templates[templateId].implementation != address(0)) {
            revert TemplateAlreadyExists();
        }
        
        templates[templateId] = StrategyTemplate({
            name: name,
            version: version,
            implementation: implementation,
            isActive: true,
            createdTime: block.timestamp,
            description: description,
            riskLevel: riskLevel,
            category: category
        });
        
        templateIds.add(templateId);
        categoryTemplates[category].push(templateId);
        implementationToTemplate[implementation] = templateId;
        
        emit TemplateRegistered(templateId, implementation, name, version);
    }
    /// @dev 更新模板实现地址
    /// @param templateId 模板ID    
    /// @param newImplementation 新实现地址


    function updateTemplateImplementation(
        bytes32 templateId,
        address newImplementation
    ) external override onlyTemplateManager {
        StrategyTemplate storage template = templates[templateId];
        if (template.implementation == address(0)) revert TemplateNotFound();
        if (newImplementation == address(0)) revert InvalidTemplate();
        
        // 更新实现映射
        delete implementationToTemplate[template.implementation];
        implementationToTemplate[newImplementation] = templateId;
        
        template.implementation = newImplementation;
        template.version = string(abi.encodePacked(template.version, "+"));
    }
    /// @dev 设置模板激活状态
    /// @param templateId 模板ID    
    /// @param isActive 是否激活
    function setTemplateStatus(
        bytes32 templateId, 
        bool isActive
    ) external override onlyTemplateManager {
        StrategyTemplate storage template = templates[templateId];
        if (template.implementation == address(0)) revert TemplateNotFound();
        
        template.isActive = isActive;
        emit TemplateStatusUpdated(templateId, isActive);
    }
    /// @dev 获取模板信息
    /// @param templateId 模板ID
    function getTemplate(
        bytes32 templateId
    ) external view override returns (StrategyTemplate memory) {
        return templates[templateId];
    }
    /// @dev 获取所有活跃模板
    /// @return 活跃模板数组
    function getActiveTemplates() 
        external 
        view 
        override 
        returns (bytes32[] memory) 
    {
        bytes32[] memory activeTemplates = new bytes32[](templateIds.length());
        uint256 activeCount;
        
        for (uint256 i = 0; i < templateIds.length(); i++) {
            bytes32 templateId = templateIds.at(i);
            if (templates[templateId].isActive) {
                activeTemplates[activeCount] = templateId;
                activeCount++;
            }
        }
        
        // 调整数组大小
        bytes32[] memory result = new bytes32[](activeCount);
        for (uint256 i = 0; i < activeCount; i++) {
            result[i] = activeTemplates[i];
        }
        
        return result;
    }
    /// @dev 根据分类获取模板
    /// @param category 分类名称
    /// @return 模板ID数组
    function getTemplatesByCategory(
        string memory category
    ) external view override returns (bytes32[] memory) {
        return categoryTemplates[category];
    }
    /// @dev 获取所有模板ID
    function getAllTemplates() external view returns (bytes32[] memory) {
        return templateIds.values();
    }

    // ============ 策略创建 ============
    /// @dev 创建新的策略实例
    /// @param templateId 模板ID
    /// @param vault 关联的资金库地址
    /// @param config 策略配置参数
    function createStrategy(
        bytes32 templateId,
        address vault,
        StrategyConfig memory config //引用StrategyConfig结构体
    ) external override nonReentrant whenNotPaused returns (address strategy) {
        if (vault == address(0)) revert InvalidConfiguration();
        
        StrategyTemplate memory template = templates[templateId];
        if (template.implementation == address(0)) revert TemplateNotFound();
        if (!template.isActive) revert TemplateNotActive();
        
        // 检查资金库策略数量限制
        if (vaultStrategies[vault].length() >= maxStrategiesPerVault) {
            revert("Max strategies per vault reached");
        }
        
        // 支付创建费用（如果有）
        if (creationFee > 0) {
            // 这里可以添加费用支付逻辑
        }
        
        // 使用克隆模式创建策略实例
        strategy = template.implementation.clone();
        
        // 初始化策略 - 需要BaseStrategy有initialize方法
        try BaseStrategy(strategy).initialize(
            vault,
            config.maxInvestmentRatio != 0 ? config.maxInvestmentRatio : 8000, // 默认80%
            config.harvestInterval != 0 ? config.harvestInterval : 86400, // 默认24小时
            template.riskLevel,
            msg.sender
        ) {
            // 初始化成功
        } catch {
            revert StrategyCreationFailed();
        }
        
        // 配置策略参数
        _configureStrategy(strategy, config);
        
        // 记录实例信息
        strategyInstances[strategy] = StrategyInstance({
            strategy: strategy,
            vault: vault,
            template: template.implementation,
            deployedTime: block.timestamp,
            isActive: true,
            totalDeployed: 0
        });
        
        vaultStrategies[vault].add(strategy);
        strategyToCreator[strategy] = msg.sender;
        templateDeploymentCount[templateId]++;
        totalStrategiesCreated++;
        totalStrategiesActive++;
        
        emit StrategyCreated(strategy, vault, templateId, msg.sender);
    }
    /// @dev 克隆现有策略实例
    /// @param templateId 模板ID
    /// @param vault 关联的资金库地址
    /// @param sourceStrategy 源策略地址    
    /// @return strategy 新策略地址
    function cloneStrategy(
        bytes32 templateId,
        address vault,
        address sourceStrategy
    ) external override nonReentrant whenNotPaused returns (address strategy) {
        if (!isValidStrategy(sourceStrategy)) revert InvalidStrategy();
        
        StrategyInstance memory sourceInstance = strategyInstances[sourceStrategy];
        StrategyConfig memory config = StrategyConfig({
            maxInvestmentRatio: BaseStrategy(sourceStrategy).maxInvestmentRatio(),
            harvestInterval: BaseStrategy(sourceStrategy).harvestInterval(),
            performanceFee: defaultPerformanceFee,
            keeper: defaultKeeper,
            treasury: defaultTreasury,
            chainId: block.chainid
        });
        
        return createStrategy(templateId, vault, config);
    }

    // ============ 策略管理 ============
    /// @dev 获取某资金库的所有策略
    /// @param vault 资金库地址
    /// @return 策略地址数组
    function getVaultStrategies(
        address vault
    ) external view override returns (address[] memory) {
        return vaultStrategies[vault].values();
    }
    /// @dev 获取策略实例
    function getStrategyInstance(
        address strategy
    ) external view override returns (StrategyInstance memory) {
        return strategyInstances[strategy];
    }
    /// @dev 检查策略是否有效
    /// @param strategy 策略地址
    /// @return 是否有效
    function isValidStrategy(address strategy) 
        public 
        view 
        override 
        returns (bool) 
    {
        return strategyInstances[strategy].strategy != address(0) && 
               strategyInstances[strategy].isActive;
    }
    /// @dev 获取策略创建者
    /// @param strategy 策略地址
    /// @return 创建者地址

    function getStrategyCreator(address strategy) 
        external 
        view 
        override 
        returns (address) 
    {
        return strategyToCreator[strategy];
    }
    /// @dev 设置策略激活状态
    /// @param strategy 策略地址
    /// @param isActive 是否激活

    function setStrategyStatus(address strategy, bool isActive) external onlyRole(ADMIN_ROLE) {
        StrategyInstance storage instance = strategyInstances[strategy];
        if (instance.strategy == address(0)) revert InvalidStrategy();
        
        instance.isActive = isActive;
        if (isActive) {
            totalStrategiesActive++;
        } else {
            totalStrategiesActive = totalStrategiesActive > 0 ? totalStrategiesActive - 1 : 0;
        }
        
        emit StrategyStatusUpdated(strategy, isActive);
    }

    // ============ 升级管理 ============
    /// @dev 升级策略到新模板
    /// @param oldStrategy 旧策略地址/ 
    /// @param newTemplateId 新模板ID
    /// @param config 新策略配置参数
    /// @return newStrategy 新策略地址
    function upgradeStrategy(
        address oldStrategy,
        bytes32 newTemplateId,
        StrategyConfig memory config
    ) external override onlyRole(ADMIN_ROLE) returns (address newStrategy) {
        if (!isValidStrategy(oldStrategy)) revert InvalidStrategy();
        
        StrategyInstance memory oldInstance = strategyInstances[oldStrategy];
        
        // 创建新策略
        newStrategy = createStrategy(newTemplateId, oldInstance.vault, config);
        
        // 迁移资金
        _migrateStrategyFunds(oldStrategy, newStrategy);
        
        // 停用旧策略
        strategyInstances[oldStrategy].isActive = false;
        totalStrategiesActive--;
        
        emit StrategyUpgraded(oldStrategy, newStrategy, oldInstance.vault);
    }
    /// @dev 检查策略是否可以升级到新模板
    /// @param strategy 策略地址
    /// @param newTemplateId 新模板ID
    /// @return 是否可以升级
    function canUpgradeStrategy(
        address strategy, 
        bytes32 newTemplateId
    ) external view override returns (bool) {
        if (!isValidStrategy(strategy)) return false;
        
        StrategyTemplate memory newTemplate = templates[newTemplateId];
        if (newTemplate.implementation == address(0) || !newTemplate.isActive) {
            return false;
        }
        
        // 检查风险等级兼容性（可以添加更多兼容性检查）
        StrategyInstance memory instance = strategyInstances[strategy];
        StrategyTemplate memory currentTemplate = templates[
            implementationToTemplate[instance.template]
        ];
        
        return newTemplate.riskLevel <= currentTemplate.riskLevel;
    }
    /// @dev 获取推荐的升级模板
    /// @param strategy 策略地址
    /// @return 推荐的模板ID（如果有）
    function getRecommendedUpgrade(address strategy) 
        external 
        view 
        override 
        returns (bytes32) 
    {
        if (!isValidStrategy(strategy)) return bytes32(0);
        
        StrategyInstance memory instance = strategyInstances[strategy];
        bytes32 currentTemplateId = implementationToTemplate[instance.template];
        StrategyTemplate memory currentTemplate = templates[currentTemplateId];
        
        // 寻找同分类的更高版本模板（简化逻辑）
        for (uint256 i = 0; i < templateIds.length(); i++) {
            bytes32 templateId = templateIds.at(i);
            StrategyTemplate memory template = templates[templateId];
            
            if (template.isActive && 
                keccak256(abi.encodePacked(template.category)) == 
                keccak256(abi.encodePacked(currentTemplate.category)) &&
                template.riskLevel <= currentTemplate.riskLevel &&
                templateId != currentTemplateId) {
                return templateId;
            }
        }
        
        return bytes32(0);
    }

    // ============ 统计分析 ============
    /// @dev 获取工厂整体统计数据
    /// @return totalTemplates 模板总数
    /// @return totalStrategies 策略总数
    /// @return activeStrategies 活跃策略数
    /// @return totalTVL 工厂总TVL
    function getFactoryStats() 
        external 
        view 
        override 
        returns (uint256, uint256, uint256, uint256) 
    {
        return (
            templateIds.length(),      // totalTemplates
            totalStrategiesCreated,    // totalStrategies
            totalStrategiesActive,     // activeStrategies
            factoryTotalTVL           // totalTVL
        );
    }
    /// @dev 获取各分类的策略统计
    /// @return categories 分类名称数组
    /// @return counts 每个分类的策略数量   
    function getCategoryStats() 
        external 
        view 
        override 
        returns (string[] memory, uint256[] memory) 
    {
        // 收集所有分类
        string[] memory allCategories = new string[](templateIds.length());
        uint256 categoryCount;
        mapping(string => bool) memory categoryExists;
        
        for (uint256 i = 0; i < templateIds.length(); i++) {
            bytes32 templateId = templateIds.at(i);
            string memory category = templates[templateId].category;
            
            if (!categoryExists[category]) {
                allCategories[categoryCount] = category;
                categoryExists[category] = true;
                categoryCount++;
            }
        }
        
        // 统计每个分类的策略数量
        string[] memory categories = new string[](categoryCount);
        uint256[] memory counts = new uint256[](categoryCount);
        
        for (uint256 i = 0; i < categoryCount; i++) {
            categories[i] = allCategories[i];
            counts[i] = categoryTemplates[categories[i]].length;
        }
        
        return (categories, counts);
    }
    /// @dev 获取模板的统计数据
    /// @param templateId 模板ID/
    /// @return deploymentCount 部署次数
    /// @return templateTVL 模板总TVL
    /// @return successRate 成功率（活跃策略/总部署）
    function getTemplateStats(bytes32 templateId) 
        external 
        view 
        override 
        returns (uint256, uint256, uint256) 
    {
        StrategyTemplate memory template = templates[templateId];
        if (template.implementation == address(0)) revert TemplateNotFound();
        
        uint256 deploymentCount = templateDeploymentCount[templateId];
        uint256 templateTVL = templateTotalTVL[templateId];
        uint256 successRate = deploymentCount > 0 ? 
            (totalStrategiesActive * 10000) / deploymentCount : 0;
            
        return (deploymentCount, templateTVL, successRate);
    }
    /// @dev 更新策略的TVL（应由策略合约调用）
    /// @param strategy 策略地址
    /// @param tvl 新的TVL值

    function updateStrategyTVL(address strategy, uint256 tvl) external {
        // 这个函数应该只能由特定角色调用，用于更新TVL
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert Unauthorized();
        
        StrategyInstance storage instance = strategyInstances[strategy];
        if (instance.strategy == address(0)) revert InvalidStrategy();
        
        bytes32 templateId = implementationToTemplate[instance.template];
        
        // 更新TVL统计
        factoryTotalTVL = factoryTotalTVL + tvl - instance.totalDeployed;
        templateTotalTVL[templateId] = templateTotalTVL[templateId] + tvl - instance.totalDeployed;
        instance.totalDeployed = tvl;
    }

    // ============ 管理员功能 ============
    /// @dev 设置工厂默认配置
    /// @param _defaultKeeper 默认执行者地址
    /// @param _defaultTreasury 默认国库地址
    /// @param _defaultPerformanceFee 默认性能费用  
    function setDefaultConfig(
        address _defaultKeeper,
        address _defaultTreasury,
        uint256 _defaultPerformanceFee
    ) external override onlyRole(ADMIN_ROLE) {
        defaultKeeper = _defaultKeeper;
        defaultTreasury = _defaultTreasury;
        defaultPerformanceFee = _defaultPerformanceFee;
        
        emit FactoryConfigUpdated(
            _defaultKeeper,
            _defaultTreasury,
            _defaultPerformanceFee,
            creationFee
        );
    }
    /// @dev 设置创建费用
    /// @param _creationFee 创建费用
    function setCreationFee(uint256 _creationFee) external override onlyRole(ADMIN_ROLE) {
        creationFee = _creationFee;
        
        emit FactoryConfigUpdated(
            defaultKeeper,
            defaultTreasury,
            defaultPerformanceFee,
            _creationFee
        );
    }
    /// @dev 暂停或恢复工厂操作
    /// @param paused 是否暂停
    function setFactoryPaused(bool paused) external override onlyRole(ADMIN_ROLE) {
        factoryPaused = paused;
    }
    /// @dev 获取工厂当前状态
    /// @return paused 是否暂停
    /// @return fee 创建费用
    /// @return keeper 默认执行者地址
    function getFactoryStatus() 
        external 
        view 
        override 
        returns (bool, uint256, address) 
    {
        return (factoryPaused, creationFee, defaultKeeper);
    }
    /// @dev 设置每个资金库的最大策略数量
    /// @param maxStrategies 最大策略数量
    
    function setMaxStrategiesPerVault(uint256 maxStrategies) external onlyRole(ADMIN_ROLE) {
        maxStrategiesPerVault = maxStrategies;
    }
    /// @dev 增加模板管理员
    function addTemplateManager(address manager) external onlyRole(ADMIN_ROLE) {
        _grantRole(TEMPLATE_MANAGER_ROLE, manager);
    }
    /// @dev 移除模板管理员
    function removeTemplateManager(address manager) external onlyRole(ADMIN_ROLE) {
        _revokeRole(TEMPLATE_MANAGER_ROLE, manager);
    }

    // ============ 内部函数 ============
    /// @dev 配置策略参数
    function _configureStrategy(
        address strategy, 
        StrategyConfig memory config
    ) internal {
        BaseStrategy strategyContract = BaseStrategy(strategy);
        
        // 设置Keeper
        address keeper = config.keeper != address(0) ? config.keeper : defaultKeeper;
        if (keeper != address(0)) {
            strategyContract.setKeeper(keeper);
        }
        
        // 设置策略参数
        strategyContract.setStrategyParams(
            config.maxInvestmentRatio != 0 ? config.maxInvestmentRatio : 8000,
            config.harvestInterval != 0 ? config.harvestInterval : 86400
        );
    }
    /// @dev 迁移策略资金
    function _migrateStrategyFunds(address oldStrategy, address newStrategy) internal {
        BaseStrategy old = BaseStrategy(oldStrategy);
        BaseStrategy new_ = BaseStrategy(newStrategy);
        
        // 获取旧策略的总资产
        uint256 totalAssets = old.estimatedTotalAssets();
        if (totalAssets > 0) {
            // 从旧策略撤资
            old.withdraw(totalAssets);
            
            // 获取撤回的资金
            uint256 withdrawn = old.want().balanceOf(address(old));
            if (withdrawn > 0) {
                // 将资金转移到新策略
                old.want().transferFrom(address(old), address(new_), withdrawn);
                
                // 新策略投资
                new_.invest();
            }
        }
    }
    
    // ============ 紧急功能 ============
    /// @dev 紧急提取合约中的代币（仅管理员）
    function emergencyWithdraw(address token, uint256 amount) external onlyRole(ADMIN_ROLE) {
        IERC20(token).transfer(msg.sender, amount);
    }
    /// @dev 紧急暂停所有策略（仅管理员）
    function emergencyPauseAllStrategies() external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < templateIds.length(); i++) {
            bytes32 templateId = templateIds.at(i);
            templates[templateId].isActive = false;
        }
        factoryPaused = true;
    }
}