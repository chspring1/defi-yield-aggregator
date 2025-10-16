// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IVault.sol";
import "../interfaces/IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";//安全的转账、授权等方法
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; 
//防止重入攻击nonReentrant重入锁修饰器，引入ReentrancyGuard.sol就可以防止重入攻击
import "@openzeppelin/contracts/access/AccessControl.sol";//权限和角色管理
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title BaseVault
 * @dev MultiChain Yield Aggregator 基础资金库合约
 * 提供所有资金库共享的核心逻辑，具体资金库通过继承并实现抽象方法来完成
 */
abstract contract BaseVault is IVault, ERC20, ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    // ============ 常量 ============
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    uint256 public constant MAX_BPS = 10_000; // 100.00%
    uint256 public constant FEE_DENOMINATOR = 1e18;
    
    // ============ 不可变状态 ============
    IERC20 public immutable asset;
    
    // ============ 可变状态 ============
    address public strategy; //策略地址
    bool public stopped; //是否停止状态
    
    // 费用配置
    uint256 public managementFee = 200; // 2% (200 bps)
    uint256 public performanceFee = 2000; // 20% (2000 bps)
    address public feeReceiver;//费用接收者的地址
    
    // 限制配置
    uint256 public maxDepositLimit = type(uint256).max;
    uint256 public depositSlippageBps = 50; // 0.5%
    uint256 public withdrawSlippageBps = 50; // 0.5%
    
    // 统计信息
    uint256 public totalYieldAccumulated;
    uint256 public lastHarvestTimestamp;
    uint256 public totalDeposits;
    uint256 public totalWithdrawals;
    uint256 public highWaterMark; // 用于性能费计算的高水位标记
    
    // ============ 修饰器 ============
    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert Unauthorized();
        _;
    }//修饰器，只有admin可以调用，如果不是admin调用重置状态并报错
    
    modifier onlyKeeper() {
        if (!hasRole(KEEPER_ROLE, msg.sender)) revert Unauthorized();
        _;
    }//只有守护者角色可以调用被此修饰器装饰的函数
    
    modifier whenNotStopped() {
        if (stopped) revert EmergencyStopped();
        _;
    }//定义了一个是否停止的状态，如果状态为真，则revert并报错
    
    modifier onlyStrategy() {
        if (msg.sender != strategy) revert Unauthorized();
        _;
    }//只允许当前设置的策略合约地址调用被此修饰器装饰的函数只有策略地址才可以报告盈亏


    // ============ 构造函数 ============
    constructor(
        IERC20 _asset,//设置基础资产地址
        string memory _name, //基础资产的名称
        string memory _symbol,//基础资产的符号
        address _admin //管理员地址
    ) ERC20(_name, _symbol) {
        if (address(_asset) == address(0)) revert ZeroAmount();
        
        asset = _asset; //资产地址
        feeReceiver = _admin; 
        
        _setupRole(ADMIN_ROLE, _admin); //业务管理员
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);//超级管理员
        _setupRole(KEEPER_ROLE, _admin); //守护者角色
    }
    
    // ============ 抽象方法（必须由子类实现） ============
    
    /**
     * @dev 内部存款逻辑 - 必须由子类实现
     */
    function _deposit(uint256 assets, address receiver) 
        internal 
        virtual 
        returns (uint256 shares); //定义了一个必须由子类实现的接口
    
    /**
     * @dev 内部取款逻辑 - 必须由子类实现  
     */
    function _withdraw(uint256 shares, address receiver, address owner) 
        internal 
        virtual 
        returns (uint256 assets);
    
    /**
     * @dev 投资到策略 - 必须由子类实现
     */
    function _investToStrategy() internal virtual;
    
    /**
     * @dev 从策略撤资 - 必须由子类实现
     */
    function _withdrawFromStrategy(uint256 assets) internal virtual returns (uint256);

    // ============ 存款功能 ============
    /// @notice 存款指定数量的基础资产，并铸造相应数量的份额给接收者
    /// @param assets 要存入的基础资产数量
    /// @param receiver 接收铸造份额的地址
    /// @return shares 铸造给接收者的份额数量
    function deposit(uint256 assets, address receiver)  
        external  //表示该接口只能被外部调用
        override  //重写接口
        nonReentrant //防止重入攻击修饰器
        whenNotStopped //当没有停止是才可以调用此函数
        returns (uint256 shares) 
    {
        if (assets == 0) revert ZeroAmount(); //如果存款金额为0，报错
        if (assets > maxDeposit(receiver)) revert MaxDepositExceeded(); //如果存款金额大于最大存款限额，报错
        
        shares = _deposit(assets, receiver); //调用内部存款逻辑
        if (shares == 0) revert ZeroAmount(); //如果铸造份额为0，报错
        
        totalDeposits += assets; //更新总存款统计
        emit Deposit(msg.sender, receiver, assets, shares); //触发存款事件
    }
    /// @notice 存款指定数量的基础资产，带滑点保护
    /// @param assets 要存入的基础资产数量
    /// @param receiver 接收铸造份额的地址
    /// @param minShares 最小接受的铸造份额数量
    /// @return shares 铸造给接收者的份额数量
    function deposit(uint256 assets, address receiver, uint256 minShares) 
        external 
        override 
        nonReentrant 
        whenNotStopped 
        returns (uint256 shares) 
    {
        if (assets == 0) revert ZeroAmount();
        if (assets > maxDeposit(receiver)) revert MaxDepositExceeded();
        
        uint256 estimatedShares = convertToShares(assets);
        uint256 minAcceptedShares = estimatedShares * (MAX_BPS - depositSlippageBps) / MAX_BPS;
        if (minShares < minAcceptedShares) revert SlippageTooHigh();
        
        shares = _deposit(assets, receiver);
        if (shares < minShares) revert SlippageTooHigh();
        
        totalDeposits += assets;
        emit Deposit(msg.sender, receiver, assets, shares);
    }
    /// @notice 使用ERC-2612许可进行存款，带滑点保护
    /// @param assets 要存入的基础资产数量
    /// @param receiver 接收铸造份额的地址
    /// @param deadline 签名过期时间
    /// @param v, r, s 签名参数
    function depositWithPermit(
        uint256 assets,
        address receiver,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override nonReentrant whenNotStopped returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount(); //如果存款金额为0，报错
        if (assets > maxDeposit(receiver)) revert MaxDepositExceeded();//如果存款金额大于最大存款限额，报错
        
        // 使用 ERC-2612 许可验证是许可成功，如果许可成功存款，如果许可校验失败，则报错
        //使用try-catch来捕获许可失败的异常
        try IERC20Permit(address(asset)).permit(
            msg.sender, 
            address(this), 
            assets, 
            deadline, v, r, s
        ) {
            // 许可成功，继续存款
        } catch {
            revert InvalidSignature();//如果许可失败，报错
        }
        
        shares = _deposit(assets, receiver);
        totalDeposits += assets;
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    // ============ 取款功能 ============
    
    function withdraw(
        uint256 shares,
        address receiver,
        address owner
    ) external override nonReentrant whenNotStopped returns (uint256 assets) {
        if (shares == 0) revert ZeroAmount();
        if (shares > balanceOf(owner)) revert InsufficientShares();
        
        assets = _withdraw(shares, receiver, owner);
        if (assets == 0) revert ZeroAmount();
        
        totalWithdrawals += assets;
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }
    
    function withdraw(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minAssets
    ) external override nonReentrant whenNotStopped returns (uint256 assets) {
        if (shares == 0) revert ZeroAmount();
        if (shares > balanceOf(owner)) revert InsufficientShares();
        
        uint256 estimatedAssets = convertToAssets(shares);
        uint256 minAcceptedAssets = estimatedAssets * (MAX_BPS - withdrawSlippageBps) / MAX_BPS;
        if (minAssets < minAcceptedAssets) revert SlippageTooHigh();
        
        assets = _withdraw(shares, receiver, owner);
        if (assets < minAssets) revert SlippageTooHigh();
        
        totalWithdrawals += assets;
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }
    /// @notice 取出指定数量的基础资产，带滑点保护
    /// @param assets 要取出的基础资产数量
    /// @param receiver 接收取出资产的地址
    /// @param owner 份额所有者地址
    /// @return shares 消耗的份额数量
    function withdrawAssets(
        uint256 assets,
        address receiver,
        address owner
    ) external override nonReentrant whenNotStopped returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        
        shares = convertToShares(assets);//计算资产对应的份额
        if (shares > balanceOf(owner)) revert InsufficientShares(); //如果铸造份额大于拥有者的余额，报错
        if (shares == 0) revert ZeroAmount();//如果铸造份额为0，报错
        
        uint256 actualAssets = _withdraw(shares, receiver, owner); //调用内部取款逻辑转账
        if (actualAssets < assets) revert NotEnoughLiquidity();
        
        totalWithdrawals += actualAssets;
        emit Withdraw(msg.sender, receiver, owner, actualAssets, shares);
    }

    // ============ 视图函数 ============
    //查询自己的份额余额+托管资产余额
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this)) + _strategyAssets();
    }
    //查询份额转换为资产对应的数量
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : shares * totalAssets() / supply;
    }
    //查询资产转换为份额对应的数量
    function convertToShares(uint256 assets) public view override returns (uint256) {
        uint256 _totalAssets = totalAssets();
        return _totalAssets == 0 ? assets : assets * totalSupply() / _totalAssets;
    }
    //查询APY年化收益率
    function getAPY() external view override returns (uint256) {
        if (totalAssets() == 0 || totalSupply() == 0) return 0;
        
        // 简化版APY计算，实际应该基于历史收益数据
        uint256 estimatedStrategyAPY = strategy == address(0) ? 0 : IStrategy(strategy).getAPY();
        return estimatedStrategyAPY;
    }
    //累计总收益
    function totalYield() external view override returns (uint256) {
        return totalYieldAccumulated;
    }
    //查询当前使用的策略地址
    function activeStrategy() external view override returns (address) {
        return strategy;
    }
    //查询当前使用的基础资产地址
    function asset() external view override returns (address) {
        return address(asset);
    }
    //查询当前的费用配置
    function getFees() external view override returns (uint256, uint256) {
        return (managementFee, performanceFee);
    }
    //查询最大可存款数量
    function maxDeposit(address) public view override returns (uint256) {
        if (stopped) return 0;
        uint256 currentAssets = totalAssets();
        return currentAssets >= maxDepositLimit ? 0 : maxDepositLimit - currentAssets;
    }
    //查询是否处于停止状态
    function isStopped() external view override returns (bool) {
        return stopped;
    }
    //查询代币的元数据
    function metadata() external view override returns (string memory, string memory, uint8) {
        return (name(), symbol(), decimals());
    }
    //查询统计数据
    function getStats() external view override returns (uint256, uint256, uint256, bool) {
        return (totalDeposits, totalWithdrawals, lastHarvestTimestamp, !stopped);
    }

    // ============ 策略管理 ============
    
    /// @notice 收获策略收益，并重新投资
    /// @return harvested 实际收获的收益数量

    function harvest() external override nonReentrant returns (uint256 harvested) {
        //如果没有设置策略地址，报错
        if (strategy == address(0)) revert StrategyNotSet();
        //记录收获前的资产余额
        uint256 balanceBefore = asset.balanceOf(address(this));
        
        // 调用策略收获收益
        harvested = IStrategy(strategy).harvest();
        // 计算实际收获的收益
        uint256 balanceAfter = asset.balanceOf(address(this));//收获后的余额
        uint256 actualHarvest = balanceAfter - balanceBefore;//实际收获的收益
        
        if (actualHarvest > 0) {
            // 更新高水位标记和计算性能费
            _updateHighWaterMark(actualHarvest);
            
            // 分配费用
            uint256 fees = _collectFees(actualHarvest);
            uint256 netHarvest = actualHarvest - fees;
            
            totalYieldAccumulated += netHarvest;
            lastHarvestTimestamp = block.timestamp;
            
            // 将净收益重新投资
            if (netHarvest > 0) {
                asset.safeTransfer(address(strategy), netHarvest);
                _investToStrategy();
            }
            
            emit Harvest(actualHarvest, block.timestamp);
        }
        
        return actualHarvest;
    }
    /// @notice 迁移到新的策略合约
    /// @param newStrategy 新的策略合约地址

    function migrateStrategy(address newStrategy) external override onlyAdmin {
        if (newStrategy == address(0)) revert InvalidStrategy();
        if (strategy == address(0)) revert StrategyNotSet();
        
        address oldStrategy = strategy;
        
        // 从旧策略撤资所有资金
        uint256 strategyBalance = _strategyAssets();
        if (strategyBalance > 0) {
            _withdrawFromStrategy(strategyBalance);
        }
        
        // 更新策略
        strategy = newStrategy;
        
        // 将资金转移到新策略
        uint256 vaultBalance = asset.balanceOf(address(this));
        if (vaultBalance > 0) {
            asset.safeTransfer(newStrategy, vaultBalance);
            _investToStrategy();
        }
        
        emit StrategyUpdated(oldStrategy, newStrategy);
    }
    /// @notice 策略报告利润
    /// @param profit 报告的利润数量
    /// @dev 仅策略合约可调用   
    function reportProfit(uint256 profit) external override onlyStrategy {
        if (profit > 0) {
            totalYieldAccumulated += profit;
            _updateHighWaterMark(profit);
            emit Harvest(profit, block.timestamp);
        }
    }
    /// @notice 策略报告损失
    /// @param loss 报告的损失数量
    /// @dev 仅策略合约可调用   
    function reportLoss(uint256 loss) external override onlyStrategy {
        // 损失报告，更新高水位标记
        if (loss > 0) {
            uint256 currentAssets = totalAssets();
            if (currentAssets + loss > highWaterMark) {
                highWaterMark = currentAssets + loss;
            }
        }
    }

    // ============ 管理员功能 ============
    /// @notice 设置费用配置
    /// @param _managementFee 管理费 (精度1e18) 最大5%
    /// @param _performanceFee 性能费 (精度1e18) 最大50 %
    /// @param _feeReceiver 费用接收者地址              
    function setFees(
        uint256 _managementFee,
        uint256 _performanceFee,
        address _feeReceiver
    ) external override onlyAdmin {
        if (_managementFee > 500) revert InvalidConfiguration(); // 最大5%
        if (_performanceFee > 5000) revert InvalidConfiguration(); // 最大50%
        if (_feeReceiver == address(0)) revert InvalidConfiguration();
        
        managementFee = _managementFee;
        performanceFee = _performanceFee;
        feeReceiver = _feeReceiver;
    }
    /// @notice 设置存款限制
    /// @param newMaxDeposit 新的最大存款限制
    function setMaxDeposit(uint256 newMaxDeposit) external override onlyAdmin {
        maxDepositLimit = newMaxDeposit;
    }
    /// @notice 紧急停止资金库操作 - 仅管理员可调用
    /// @dev 紧急停止后，存款和取款操作将被禁止
    function emergencyStop() external override onlyAdmin {
        stopped = true;
        emit EmergencyStop(true, msg.sender);
    }
    /// @notice 恢复资金库操作 - 解除紧急停止
    /// @dev 恢复后，存款和取款操作将被允许
    function resume() external override onlyAdmin {
        stopped = false;
        emit EmergencyStop(false, msg.sender);
    }
    /// @notice 转移管理员权限
    /// @param newAdmin 新的管理员地址

    function transferAdmin(address newAdmin) external override onlyAdmin {
        if (newAdmin == address(0)) revert InvalidConfiguration();
        
        _grantRole(ADMIN_ROLE, newAdmin);
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        _revokeRole(ADMIN_ROLE, msg.sender);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    /// @notice 设置守护者角色
    /// @param keeper 守护者地址
    function setKeeper(address keeper) external onlyAdmin {
        _grantRole(KEEPER_ROLE, keeper);
    }
    /// @notice 移除守护者角色
    /// @param keeper 守护者地址
    function revokeKeeper(address keeper) external onlyAdmin {
        _revokeRole(KEEPER_ROLE, keeper);
    }
    /// @notice 设置滑点
    /// @param depositSlippage 存款滑点
    /// @param withdrawSlippage 取款滑点
    function setSlippage(uint256 depositSlippage, uint256 withdrawSlippage) external onlyAdmin {
        if (depositSlippage > 500) revert InvalidConfiguration(); // 最大5%
        if (withdrawSlippage > 500) revert InvalidConfiguration(); // 最大5%
        
        depositSlippageBps = depositSlippage;
        withdrawSlippageBps = withdrawSlippage;
    }

    // ============ 内部函数 ============
    /// @notice 查询策略持有的资产数量
    /// @return 策略持有的资产数量
    function _strategyAssets() internal view returns (uint256) {
        return strategy == address(0) ? 0 : IStrategy(strategy).estimatedTotalAssets();
    }
    /// @notice 更新高水位标记
    /// @param profit 本次收获的利润
    function _updateHighWaterMark(uint256 profit) internal {
        uint256 currentAssets = totalAssets();
        if (currentAssets > highWaterMark) {
            highWaterMark = currentAssets;
        }
    }
    /// @notice 收集管理费和性能费
    /// @param profit 本次收获的利润
    /// @return totalFees 收集的总费用  
    function _collectFees(uint256 profit) internal returns (uint256 totalFees) {
        uint256 managementFeeAmount = 0;
        uint256 performanceFeeAmount = 0;
        
        // 计算管理费（基于总资产）
        if (managementFee > 0) {
            managementFeeAmount = totalAssets() * managementFee / MAX_BPS / 365 days * (block.timestamp - lastHarvestTimestamp);
            if (managementFeeAmount > 0) {
                asset.safeTransfer(feeReceiver, managementFeeAmount);
                emit FeeCollected(0, managementFeeAmount, feeReceiver);
            }
        }
        
        // 计算性能费（基于超过高水位标记的收益）
        if (performanceFee > 0 && totalAssets() > highWaterMark) {
            uint256 excessProfit = totalAssets() - highWaterMark;
            performanceFeeAmount = excessProfit * performanceFee / MAX_BPS;
            if (performanceFeeAmount > 0) {
                asset.safeTransfer(feeReceiver, performanceFeeAmount);
                emit FeeCollected(1, performanceFeeAmount, feeReceiver);
            }
        }
        
        totalFees = managementFeeAmount + performanceFeeAmount;
    }
    /// @notice 查询合约版本
    function version() external pure override returns (string memory) {
        return "1.0.0";
    }
    
    // ============ ERC2612 支持 ============
    /// @notice 使用 ERC-2612 许可进行授权将 owner 授权给 spender 使用 value 数量的代币
    /// @param owner 代币所有者地址
    /// @param spender 授权的地址
    /// @param value 授权的代币数量
    /// @param deadline 签名过期时间
    /// @param v, r, s 签名参数
    /// @dev 参考 OpenZeppelin 的 ERC20Permit 实现
    /// @dev 仅供示例，实际使用时请确保正确实现 EIP-712 域分隔符和非ces管理
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        // 使用 OpenZeppelin 的 ERC20Permit 逻辑
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");
        // 将交易数据打包成哈希
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                _useNonce(owner),
                deadline
            )
        );
        
        bytes32 hash = _hashTypedDataV4(structHash);//使用EIP-712域分隔符对结构化数据进行哈希
        address signer = ECDSA.recover(hash, v, r, s); //使用ECDSA恢复签名者地址
        require(signer == owner, "ERC20Permit: invalid signature");//验证签名者是否为所有者

        _approve(owner, spender, value);//permit 流程的最终目标：通过签名实现无 gas 费的链上授权
    }
    //记录一个nonce值，防止重放攻击
    function nonces(address owner) public view virtual override returns (uint256) {
        return _nonces[owner].current();
    }
    /// @notice 生成域分隔符，用于链下签名和链上验证
    function DOMAIN_SEPARATOR() external view virtual override returns (bytes32) {
        return _domainSeparatorV4();
    }
}