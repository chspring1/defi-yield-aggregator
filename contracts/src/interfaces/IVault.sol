// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC2612.sol";

/**
 * @title IVault
 * @dev MultiChain Yield Aggregator 资金库标准接口
 * 定义所有资金库合约必须实现的函数和事件
 */
interface IVault is IERC20, IERC2612 {
    
    // ============================================
    //                  事件定义
    // ============================================
    
    /**
     * @dev 存款事件
     * @param sender 存款调用者
     * @param owner 份额所有者
     * @param assets 存入的资产数量
     * @param shares 获得的份额数量
     */
    event Deposit(
        address indexed sender,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * @dev 取款事件
     * @param sender 取款调用者
     * @param receiver 资产接收者
     * @param owner 份额所有者
     * @param assets 取出的资产数量
     * @param shares 销毁的份额数量
     */
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * @dev 策略更新事件
     * @param oldStrategy 旧策略地址
     * @param newStrategy 新策略地址
     */
    event StrategyUpdated(
        address indexed oldStrategy,
        address indexed newStrategy
    );

    /**
     * @dev 收益收获事件
     * @param harvestedAmount 收获的收益数量
     * @param timestamp 收获时间戳
     */
    event Harvest(
        uint256 harvestedAmount,
        uint256 timestamp
    );

    /**
     * @dev 紧急停止事件
     * @param stopped 是否停止
     * @param caller 调用者地址
     */
    event EmergencyStop(
        bool stopped,
        address indexed caller
    );

    /**
     * @dev 费用收取事件
     * @param feeType 费用类型 (0=管理费, 1=性能费)
     * @param feeAmount 费用金额
     * @param feeReceiver 费用接收者
     */
    event FeeCollected(
        uint256 indexed feeType,
        uint256 feeAmount,
        address feeReceiver
    );

    // ============================================
    //                  错误定义
    // ============================================

    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientShares();
    error Unauthorized();
    error StrategyNotSet();
    error EmergencyStopped();
    error PermitExpired();
    error InvalidSignature();
    error InvalidStrategy();
    error MaxDepositExceeded();
    error MaxWithdrawExceeded();
    error SlippageTooHigh();
    error NotEnoughLiquidity();

    // ============================================
    //                  存款功能
    // ============================================

    /**
     * @dev 存款函数 - 用户存入资产获取份额
     * @param assets 存款资产数量
     * @param receiver 份额接收者地址
     * @return shares 获得的份额数量
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @dev ERC-2612 许可签名存款
     * @param assets 存款资产数量
     * @param receiver 份额接收者地址
     * @param deadline 签名过期时间
     * @param v, r, s 签名参数
     * @return shares 获得的份额数量
     */
    function depositWithPermit(
        uint256 assets,
        address receiver,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 shares);

    /**
     * @dev 带滑点保护的存款
     * @param assets 存款资产数量
     * @param receiver 份额接收者地址
     * @param minShares 最小接受份额数量
     * @return shares 获得的份额数量
     */
    function deposit(
        uint256 assets,
        address receiver,
        uint256 minShares
    ) external returns (uint256 shares);

    // ============================================
    //                  取款功能
    // ============================================

    /**
     * @dev 取款函数 - 用户使用份额取回资产
     * @param shares 取款份额数量
     * @param receiver 资产接收者地址
     * @param owner 份额所有者地址
     * @return assets 获得的资产数量
     */
    function withdraw(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    /**
     * @dev 带滑点保护的取款
     * @param shares 取款份额数量
     * @param receiver 资产接收者地址
     * @param owner 份额所有者地址
     * @param minAssets 最小接受资产数量
     * @return assets 获得的资产数量
     */
    function withdraw(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minAssets
    ) external returns (uint256 assets);

    /**
     * @dev 基于资产数量的取款
     * @param assets 取款资产数量
     * @param receiver 资产接收者地址
     * @param owner 份额所有者地址
     * @return shares 销毁的份额数量
     */
    function withdrawAssets(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    // ============================================
    //                  视图函数
    // ============================================

    /**
     * @dev 获取总资产价值
     * @return 总管理的资产数量
     */
    function totalAssets() external view returns (uint256);

    /**
     * @dev 将份额转换为资产
     * @param shares 份额数量
     * @return 对应的资产价值
     */
    function convertToAssets(uint256 shares) external view returns (uint256);

    /**
     * @dev 将资产转换为份额
     * @param assets 资产数量
     * @return 对应的份额数量
     */
    function convertToShares(uint256 assets) external view returns (uint256);

    /**
     * @dev 获取预估年化收益率 (APY)
     * @return 当前APY (精度1e18，如 10% = 0.1e18)
     */
    function getAPY() external view returns (uint256);

    /**
     * @dev 获取累计总收益
     * @return 累计收益总额
     */
    function totalYield() external view returns (uint256);

    /**
     * @dev 获取当前活跃策略
     * @return 策略合约地址
     */
    function activeStrategy() external view returns (address);

    /**
     * @dev 获取基础资产地址
     * @return 基础资产合约地址
     */
    function asset() external view returns (address);

    /**
     * @dev 获取资金库费用配置
     * @return managementFee 管理费 (精度1e18)
     * @return performanceFee 性能费 (精度1e18)
     */
    function getFees() external view returns (uint256 managementFee, uint256 performanceFee);

    /**
     * @dev 获取资金库最大容量限制
     * @return 最大存款限制
     */
    function maxDeposit() external view returns (uint256);

    /**
     * @dev 检查资金库是否处于紧急停止状态
     * @return 是否停止
     */
    function isStopped() external view returns (bool);

    // ============================================
    //                  策略管理
    // ============================================

    /**
     * @dev 收益 harvest 函数 - 策略调用收取收益
     * @return harvested 收获的收益数量
     */
    function harvest() external returns (uint256 harvested);

    /**
     * @dev 策略迁移函数
     * @param newStrategy 新策略地址
     */
    function migrateStrategy(address newStrategy) external;

    /**
     * @dev 紧急停止函数 - 仅管理员可调用
     */
    function emergencyStop() external;

    /**
     * @dev 恢复函数 - 解除紧急停止
     */
    function resume() external;

    /**
     * @dev 报告收益函数 - 策略调用报告收益
     * @param profit 收益金额
     */
    function reportProfit(uint256 profit) external;

    /**
     * @dev 报告损失函数 - 策略调用报告损失
     * @param loss 损失金额
     */
    function reportLoss(uint256 loss) external;

    // ============================================
    //                  管理员功能
    // ============================================

    /**
     * @dev 设置费用配置
     * @param managementFee 管理费 (精度1e18)
     * @param performanceFee 性能费 (精度1e18)
     * @param feeReceiver 费用接收者
     */
    function setFees(
        uint256 managementFee,
        uint256 performanceFee,
        address feeReceiver
    ) external;

    /**
     * @dev 设置存款限制
     * @param newMaxDeposit 新的最大存款限制
     */
    function setMaxDeposit(uint256 newMaxDeposit) external;

    /**
     * @dev 转移管理员权限
     * @param newAdmin 新的管理员地址
     */
    function transferAdmin(address newAdmin) external;

    // ============================================
    //                  扩展功能
    // ============================================

    /**
     * @dev 获取资金库版本信息
     * @return 版本字符串
     */
    function version() external view returns (string memory);

    /**
     * @dev 获取资金库元数据
     * @return name 资金库名称
     * @return symbol 资金库符号
     * @return decimals 精度
     */
    function metadata() external view returns (
        string memory name,
        string memory symbol,
        uint8 decimals
    );

    /**
     * @dev 获取资金库统计信息
     * @return totalDeposits 总存款次数
     * @return totalWithdrawals 总取款次数
     * @return lastHarvest 最后收获时间
     * @return isActive 是否活跃
     */
    function getStats() external view returns (
        uint256 totalDeposits,
        uint256 totalWithdrawals,
        uint256 lastHarvest,
        bool isActive
    );
}