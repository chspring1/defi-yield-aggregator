// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../base/BaseVault.sol";
import "../interfaces/IStrategy.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title SimpleVault
 * @dev 简单资金库实现 - 基础的资金库功能，支持单一策略
 * 作为其他复杂资金库的参考实现
 */
contract SimpleVault is BaseVault {
    using Math for uint256;

    // ============ 事件 ============
    event StrategyInvested(uint256 amount);
    event StrategyDivested(uint256 amount);
    event FeesCollected(uint256 managementFee, uint256 performanceFee);

    // ============ 构造函数 ============
    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _admin
    ) BaseVault(_asset, _name, _symbol, _admin) {
        // 初始化完成
    }

    // ============ 核心存款逻辑实现 ============
    /// @dev 存款实现 - 计算份额并处理资产转移
    /// @param assets 存入的资产数量
    /// @param receiver 份额接收者地址
    /// @return shares 获得的份额数量
    function _deposit(uint256 assets, address receiver) 
        internal 
        override 
        returns (uint256 shares) 
    {
        // 从用户转移资产
        asset.safeTransferFrom(msg.sender, address(this), assets);
        
        // 计算份额（考虑现有资产和份额）
        uint256 supply = totalSupply();
        if (supply == 0) {
            shares = assets;
        } else {
            shares = assets * supply / totalAssets();
        }
        
        // 铸造份额给接收者
        _mint(receiver, shares);
        
        // 自动投资到策略（如果有策略且未停止）
        if (strategy != address(0) && !stopped) {
            _autoInvest();
        }
    }

    // ============ 核心取款逻辑实现 ============
    /// @dev 取款实现 - 计算资产并处理份额销毁和资产转移
    /// @param shares 销毁的份额数量
    /// @param receiver 资产接收者地址
    /// @param owner 份额所有者地址
    /// @return assets 提取的资产数量
    function _withdraw(uint256 shares, address receiver, address owner) 
        internal 
        override 
        returns (uint256 assets) 
    {
        // 计算对应的资产数量
        uint256 supply = totalSupply();
        assets = shares * totalAssets() / supply;
        
        // 如果资产不足，从策略撤资
        uint256 vaultBalance = asset.balanceOf(address(this));
        if (assets > vaultBalance && strategy != address(0)) {
            uint256 neededFromStrategy = assets - vaultBalance;
            uint256 withdrawn = _withdrawFromStrategy(neededFromStrategy);
            
            // 更新实际可用资产
            vaultBalance = asset.balanceOf(address(this));
            assets = Math.min(assets, vaultBalance);
        }
        
        // 确保不会过度取款
        assets = Math.min(assets, asset.balanceOf(address(this)));
        if (assets == 0) revert InsufficientBalance();
        
        // 销毁份额并转移资产
        _burn(owner, shares);
        asset.safeTransfer(receiver, assets);
    }

    // ============ 策略投资逻辑 ============
    /// @dev 投资到策略 - 将可用资产转移到策略并调用投资函数
    /// 如果没有设置策略或资金库已停止，则不进行任何操作
    function _investToStrategy() internal override {
        if (strategy == address(0)) return;
        if (stopped) return;
        
        uint256 available = asset.balanceOf(address(this));
        if (available == 0) return;
        
        // 转移到策略并投资
        asset.safeTransfer(strategy, available);
        IStrategy(strategy).invest();
        
        emit StrategyInvested(available);
    }

    // ============ 策略撤资逻辑 ============
    /// @dev 从策略撤资 - 请求从策略中提取指定金额
    /// @param assets 撤资金额
    /// @return 实际撤资金额
    function _withdrawFromStrategy(uint256 assets) 
        internal 
        override 
        returns (uint256) 
    {
        if (strategy == address(0)) return 0;
        
        uint256 withdrawn = IStrategy(strategy).withdraw(assets);
        emit StrategyDivested(withdrawn);
        
        return withdrawn;
    }

    // ============ 自动投资逻辑 ============
    /// @dev 自动投资 - 如果有足够的可用资产，则自动投资到策略
    /// 这里设置了一个最小自动投资阈值以避免频繁小额投资
    function _autoInvest() internal {
        uint256 available = asset.balanceOf(address(this));
        uint256 minAutoInvest = 1e6; // 最小自动投资金额
        
        if (available >= minAutoInvest) {
            _investToStrategy();
        }
    }

    // ============ 管理员功能扩展 ============
    
    /**
     * @dev 手动触发投资
     */
    function manualInvest() external onlyRole(ADMIN_ROLE) {
        _investToStrategy();
    }
    
    /**
     * @dev 手动触发从策略撤资
     * @param assets 撤资金额
     */
    function manualWithdrawFromStrategy(uint256 assets) external onlyRole(ADMIN_ROLE) returns (uint256) {
        return _withdrawFromStrategy(assets);
    }
    
    /**
     * @dev 紧急提取所有资金从策略
     */
    function emergencyWithdrawAllFromStrategy() external onlyRole(ADMIN_ROLE) returns (uint256) {
        if (strategy == address(0)) return 0;
        
        uint256 strategyAssets = IStrategy(strategy).estimatedTotalAssets();
        return _withdrawFromStrategy(strategyAssets);
    }

    // ============ 视图函数扩展 ============
    
    /**
     * @dev 获取资金库详细状态
     */
    function getVaultDetails() external view returns (
        uint256 vaultBalance,
        uint256 strategyBalance,
        uint256 totalAssetsValue,
        uint256 sharePrice,
        bool hasStrategy,
        uint256 availableLiquidity
    ) {
        vaultBalance = asset.balanceOf(address(this));
        strategyBalance = strategy == address(0) ? 0 : IStrategy(strategy).estimatedTotalAssets();
        totalAssetsValue = totalAssets();
        sharePrice = totalSupply() == 0 ? 1e18 : totalAssetsValue * 1e18 / totalSupply();
        hasStrategy = strategy != address(0);
        availableLiquidity = vaultBalance;
    }
    
    /**
     * @dev 获取策略信息
     */
    function getStrategyInfo() external view returns (
        address strategyAddress,
        string memory strategyName,
        uint256 strategyAPY,
        bool strategyActive
    ) {
        strategyAddress = strategy;
        if (strategy == address(0)) {
            return (address(0), "No Strategy", 0, false);
        }
        
        try IStrategy(strategy).name() returns (string memory name) {
            strategyName = name;
        } catch {
            strategyName = "Unknown";
        }
        
        try IStrategy(strategy).getAPY() returns (uint256 apy) {
            strategyAPY = apy;
        } catch {
            strategyAPY = 0;
        }
        
        try IStrategy(strategy).isActive() returns (bool active) {
            strategyActive = active;
        } catch {
            strategyActive = false;
        }
    }

    // ============ 收益相关功能 ============
    
    /**
     * @dev 手动触发收益收获
     */
    function manualHarvest() external onlyRole(ADMIN_ROLE) returns (uint256) {
        if (strategy == address(0)) revert StrategyNotSet();
        return harvest();
    }
    
    /**
     * @dev 自动收获（keeper调用）
     */
    function autoHarvest() external onlyRole(KEEPER_ROLE) returns (uint256) {
        if (strategy == address(0)) revert StrategyNotSet();
        return harvest();
    }

    // ============ 资金库升级支持 ============
    
    /**
     * @dev 迁移到新资金库
     * @param newVault 新资金库地址
     */
    function migrateVault(address newVault) external onlyRole(ADMIN_ROLE) {
        if (newVault == address(0)) revert InvalidConfiguration();
        if (stopped) revert EmergencyStopped();
        
        // 从策略撤资所有资金
        if (strategy != address(0)) {
            uint256 strategyAssets = IStrategy(strategy).estimatedTotalAssets();
            if (strategyAssets > 0) {
                _withdrawFromStrategy(strategyAssets);
            }
        }
        
        // 转移所有资产到新资金库
        uint256 vaultBalance = asset.balanceOf(address(this));
        if (vaultBalance > 0) {
            asset.safeTransfer(newVault, vaultBalance);
        }
        
        // 停止当前资金库
        stopped = true;
    }

    // ============ 费用管理扩展 ============
    
    /**
     * @dev 收集待处理费用
     */
    function collectFees() external onlyRole(ADMIN_ROLE) returns (uint256 totalFees) {
        if (strategy == address(0)) return 0;
        
        // 触发收获以生成收益
        uint256 harvested = harvest();
        if (harvested > 0) {
            // 费用会在harvest过程中自动收集
            totalFees = _collectFees(harvested);
            emit FeesCollected(managementFee, performanceFee);
        }
        
        return totalFees;
    }

    // ============ 重写版本信息 ============
    function version() external pure override returns (string memory) {
        return "1.0.0";
    }
    
    function name() public view override returns (string memory) {
        return super.name();
    }
    
    function symbol() public view override returns (string memory) {
        return super.symbol();
    }

    // ============ 接收以太币（如果需要） ============
    receive() external payable {}
    
    // ============ 紧急恢复功能 ============
    
    /**
     * @dev 恢复意外发送的代币（除了基础资产）
     */
    function recoverToken(address token, uint256 amount) external onlyRole(ADMIN_ROLE) {
        if (token == address(asset)) {
            revert("Cannot recover vault asset");
        }
        IERC20(token).safeTransfer(msg.sender, amount);
    }
    
    /**
     * @dev 恢复意外发送的以太币
     */
    function recoverETH(uint256 amount) external onlyRole(ADMIN_ROLE) {
        payable(msg.sender).transfer(amount);
    }
}