// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title SimpleVault
 * @dev 简单的资金库合约，演示 ReentrancyGuard 的使用
 */
contract SimpleVault is ERC20, ReentrancyGuard, AccessControl {
    // ============ 常量 ============
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // ============ 状态变量 ============
    IERC20 public immutable asset;
    bool public stopped;
    
    // ============ 事件 ============
    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 assets, uint256 shares);
    event EmergencyStop(bool stopped);
    
    // ============ 修饰器 ============
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Unauthorized");
        _;
    }
    
    modifier whenNotStopped() {
        require(!stopped, "Emergency stopped");
        _;
    }
    
    // ============ 构造函数 ============
    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _admin
    ) ERC20(_name, _symbol) {
        asset = _asset;
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }
    
    /**
     * @dev 存款函数 - 使用 nonReentrant 修饰器防止重入攻击
     * 这是 ReentrancyGuard 最重要的应用场景
     */
    function deposit(uint256 assets) 
        external 
        nonReentrant  // 🛡️ 防止重入攻击
        whenNotStopped 
        returns (uint256 shares) 
    {
        require(assets > 0, "Zero amount");
        
        // 计算应该铸造的份额
        shares = convertToShares(assets);
        
        // 从用户转入资产（外部调用 - 可能触发重入）
        asset.transferFrom(msg.sender, address(this), assets);
        
        // 铸造份额给用户
        _mint(msg.sender, shares);
        
        emit Deposit(msg.sender, assets, shares);
    }
    
    /**
     * @dev 取款函数 - 使用 nonReentrant 修饰器防止重入攻击
     * 这里的外部调用可能被恶意合约利用进行重入攻击
     */
    function withdraw(uint256 shares) 
        external 
        nonReentrant  // 🛡️ 防止重入攻击
        whenNotStopped 
        returns (uint256 assets) 
    {
        require(shares > 0, "Zero amount");
        require(shares <= balanceOf(msg.sender), "Insufficient shares");
        
        // 计算可以取出的资产数量
        assets = convertToAssets(shares);
        
        // 销毁份额
        _burn(msg.sender, shares);
        
        // 转移资产给用户（外部调用 - 可能触发重入）
        asset.transfer(msg.sender, assets);
        
        emit Withdraw(msg.sender, assets, shares);
    }
    
    // ============ 视图函数 ============
    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }
    
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }
    
    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 _totalAssets = totalAssets();
        return _totalAssets == 0 ? assets : (assets * totalSupply()) / _totalAssets;
    }
    
    // ============ 管理员功能 ============
    function emergencyStop() external onlyAdmin {
        stopped = true;
        emit EmergencyStop(true);
    }
    
    function resume() external onlyAdmin {
        stopped = false;
        emit EmergencyStop(false);
    }
}