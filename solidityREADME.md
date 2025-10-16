# MYA Platform Smart Contracts - DeFi 收益聚合智能合约

[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue.svg)](https://soliditylang.org)
[![Hardhat](https://img.shields.io/badge/Hardhat-2.26+-green.svg)](https://hardhat.org)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.4.0-orange.svg)](https://openzeppelin.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📋 合约概述

MYA Platform 智能合约系统是一个完整的去中心化金融(DeFi)收益聚合平台，实现了资金库、策略、工厂等核心合约，为用户提供安全、高效的跨链收益解决方案。

## 🏗️ 合约架构

```
contracts/src/
├── interfaces/           # 标准接口定义
│   ├── IVault.sol       # 资金库接口
│   ├── IStrategy.sol    # 策略接口
│   └── IStrategyFactory.sol # 策略工厂接口
├── base/                # 基础合约实现
│   ├── BaseVault.sol    # 资金库基础合约
│   └── BaseStrategy.sol # 策略基础合约
├── implementations/     # 具体实现合约
│   ├── SimpleVault.sol  # 简单资金库实现
│   ├── AAVEStrategy.sol # AAVE借贷策略
│   └── StrategyFactory.sol # 策略工厂合约
├── vaults/             # 多种资金库实现
├── strategies/         # 多种策略实现
└── factories/          # 工厂合约
```

## 🔗 合约地址 (测试网)

| 合约名称 | 地址 | 描述 |
|---------|------|------|
| SimpleVault | `0x...` | 简单资金库合约 |
| AAVEStrategy | `0x...` | AAVE借贷策略合约 |
| StrategyFactory | `0x...` | 策略工厂合约 |

## 📚 核心接口文档

### 1. IVault - 资金库接口

资金库是用户存入资产并获得收益的核心合约接口。

#### 核心数据结构

```solidity
// 事件定义
event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
event Withdraw(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
event Harvest(uint256 harvestedAmount, uint256 timestamp);
event EmergencyStop(bool stopped, address indexed caller);
```

#### 主要功能函数

##### 1.1 存款功能

```solidity
/**
 * @dev 基础存款 - 用户存入资产获取份额
 * @param assets 存款资产数量
 * @param receiver 份额接收者地址
 * @return shares 获得的份额数量
 */
function deposit(uint256 assets, address receiver) external returns (uint256 shares);
```

**使用示例:**
```javascript
// 存入1000 USDC
const assets = ethers.utils.parseUnits("1000", 6); // USDC 6位精度
const tx = await vault.deposit(assets, userAddress);
const receipt = await tx.wait();
const shares = receipt.events.find(e => e.event === 'Deposit').args.shares;
```

##### 1.2 带滑点保护的存款

```solidity
/**
 * @dev 带滑点保护的存款
 * @param assets 存款资产数量
 * @param receiver 份额接收者地址
 * @param minShares 最小接受份额数量
 * @return shares 获得的份额数量
 */
function deposit(uint256 assets, address receiver, uint256 minShares) external returns (uint256 shares);
```

##### 1.3 ERC-2612 许可签名存款

```solidity
/**
 * @dev 使用许可签名的存款（无需预先approve）
 * @param assets 存款资产数量
 * @param receiver 份额接收者地址
 * @param deadline 签名过期时间
 * @param v, r, s 签名参数
 */
function depositWithPermit(
    uint256 assets,
    address receiver,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s
) external returns (uint256 shares);
```

##### 1.4 取款功能

```solidity
/**
 * @dev 基础取款 - 用户使用份额取回资产
 * @param shares 取款份额数量
 * @param receiver 资产接收者地址
 * @param owner 份额所有者地址
 * @return assets 获得的资产数量
 */
function withdraw(uint256 shares, address receiver, address owner) external returns (uint256 assets);
```

**使用示例:**
```javascript
// 取款所有份额
const userShares = await vault.balanceOf(userAddress);
const tx = await vault.withdraw(userShares, userAddress, userAddress);
const receipt = await tx.wait();
const assets = receipt.events.find(e => e.event === 'Withdraw').args.assets;
```

##### 1.5 基于资产数量的取款

```solidity
/**
 * @dev 基于资产数量的取款
 * @param assets 取款资产数量
 * @param receiver 资产接收者地址
 * @param owner 份额所有者地址
 * @return shares 销毁的份额数量
 */
function withdrawAssets(uint256 assets, address receiver, address owner) external returns (uint256 shares);
```

#### 视图函数

##### 1.6 资产和份额转换

```solidity
// 获取总管理资产
function totalAssets() external view returns (uint256);

// 份额转资产
function convertToAssets(uint256 shares) external view returns (uint256);

// 资产转份额
function convertToShares(uint256 assets) external view returns (uint256);
```

**使用示例:**
```javascript
// 计算100份额对应的资产数量
const assets = await vault.convertToAssets(ethers.utils.parseEther("100"));

// 计算1000资产对应的份额数量
const shares = await vault.convertToShares(ethers.utils.parseUnits("1000", 6));
```

##### 1.7 收益信息

```solidity
// 获取当前APY
function getAPY() external view returns (uint256);

// 获取累计总收益
function totalYield() external view returns (uint256);

// 获取活跃策略
function activeStrategy() external view returns (address);
```

---

### 2. IStrategy - 策略接口

策略合约负责将资产投入各种DeFi协议以产生收益。

#### 核心功能

##### 2.1 策略投资

```solidity
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
```

##### 2.2 收益收获

```solidity
/**
 * @dev 收获收益 - 收集策略产生的收益
 * @return 收益金额
 */
function harvest() external returns (uint256);
```

##### 2.3 紧急功能

```solidity
/**
 * @dev 紧急撤资 - 提取所有资金
 * @return 提取的总金额
 */
function emergencyExit() external returns (uint256);
```

#### 状态查询

```solidity
// 估算策略管理的总资产
function estimatedTotalAssets() external view returns (uint256);

// 获取策略APY
function getAPY() external view returns (uint256);

// 获取风险评分 (1-10)
function riskScore() external view returns (uint8);

// 获取策略名称和版本
function name() external view returns (string memory);
function version() external view returns (string memory);
```

---

## 🔧 合约部署配置

### 环境要求

- **Node.js** 18+
- **Hardhat** 2.26+
- **Solidity** 0.8.20
- **OpenZeppelin Contracts** 5.4.0

### 项目设置

1. **安装依赖**
```bash
cd contracts
npm install
```

2. **环境配置**
```bash
# 创建 .env 文件
cp .env.example .env

# 配置必要的环境变量
PRIVATE_KEY=your_private_key
INFURA_API_KEY=your_infura_key
ETHERSCAN_API_KEY=your_etherscan_key
```

3. **编译合约**
```bash
npm run compile
```

### Hardhat 配置

```javascript
// hardhat.config.js
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
    // 添加其他网络配置...
  },
};
```

## 🚀 部署指南

### 本地开发网络

1. **启动本地节点**
```bash
npm run node
```

2. **部署合约**
```bash
npm run deploy:local
```

### 测试网部署

```bash
# 部署到测试网
npm run deploy:testnet

# 验证合约
npm run verify -- --network testnet DEPLOYED_CONTRACT_ADDRESS
```

### 主网部署

```bash
# 部署到主网 (谨慎操作)
npm run deploy:mainnet

# 验证合约
npm run verify -- --network mainnet DEPLOYED_CONTRACT_ADDRESS
```

## 📋 合约实现详解

### 1. SimpleVault 合约

#### 功能特性

- ✅ **ERC-4626 兼容** - 标准化的资金库代币
- ✅ **单策略支持** - 支持一个活跃策略
- ✅ **自动投资** - 存款时自动投资到策略
- ✅ **费用管理** - 支持管理费和性能费
- ✅ **紧急停止** - 管理员可紧急停止操作
- ✅ **滑点保护** - 防止MEV攻击
- ✅ **权限控制** - 基于角色的访问控制

#### 部署参数

```javascript
// 部署 SimpleVault
const SimpleVault = await ethers.getContractFactory("SimpleVault");
const vault = await SimpleVault.deploy(
    usdcAddress,           // 基础资产 (USDC)
    "MYA USDC Vault",      // 资金库名称
    "myaUSDC",             // 资金库符号
    adminAddress           // 管理员地址
);
```

#### 使用示例

```javascript
// 1. 存款到资金库
const depositAmount = ethers.utils.parseUnits("1000", 6); // 1000 USDC
await usdc.approve(vault.address, depositAmount);
const shares = await vault.deposit(depositAmount, userAddress);

// 2. 查看份额价值
const sharePrice = await vault.convertToAssets(ethers.utils.parseEther("1"));
console.log(`每份额价值: ${ethers.utils.formatUnits(sharePrice, 6)} USDC`);

// 3. 取款
const userShares = await vault.balanceOf(userAddress);
const assets = await vault.withdraw(userShares, userAddress, userAddress);

// 4. 管理员设置策略
await vault.setStrategy(strategyAddress);

// 5. 触发收益收获
const harvested = await vault.harvest();
```

### 2. AAVEStrategy 策略合约

#### 功能特性

- 🏦 **AAVE 集成** - 将资产存入AAVE借贷池
- 📈 **收益优化** - 自动收获AAVE奖励代币
- ⚡ **快速流动性** - 支持即时取款
- 🛡️ **风险控制** - 监控借贷健康度
- 🔄 **自动复投** - 收益自动再投资

#### 策略参数

```javascript
// 部署 AAVEStrategy
const AAVEStrategy = await ethers.getContractFactory("AAVEStrategy");
const strategy = await AAVEStrategy.deploy(
    vaultAddress,          // 关联的资金库
    usdcAddress,           // 投资资产 (USDC)
    aavePoolAddress,       // AAVE借贷池地址
    incentivesController,  // AAVE奖励控制器
    adminAddress           // 管理员地址
);
```

### 3. StrategyFactory 工厂合约

#### 功能特性

- 🏭 **策略创建** - 批量创建策略合约
- 📝 **注册管理** - 维护策略注册表
- 🔐 **权限控制** - 只有授权用户可创建策略
- 📊 **统计信息** - 跟踪创建的策略数量

#### 使用示例

```javascript
// 创建新的AAVE策略
const tx = await strategyFactory.createAAVEStrategy(
    vaultAddress,
    assetAddress,
    "AAVE USDC Strategy v1"
);
const receipt = await tx.wait();
const strategyAddress = receipt.events.find(e => e.event === 'StrategyCreated').args.strategy;
```

## 🧪 测试指南

### 单元测试

```bash
# 运行所有测试
npm test

# 运行特定测试文件
npx hardhat test test/SimpleVault.test.js

# 运行覆盖率测试
npm run test:coverage
```

### 测试示例

```javascript
// test/SimpleVault.test.js
describe("SimpleVault", function () {
  let vault, usdc, admin, user1;

  beforeEach(async function () {
    [admin, user1] = await ethers.getSigners();
    
    // 部署USDC模拟合约
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    usdc = await MockERC20.deploy("USD Coin", "USDC", 6);
    
    // 部署资金库
    const SimpleVault = await ethers.getContractFactory("SimpleVault");
    vault = await SimpleVault.deploy(
      usdc.address,
      "Test Vault",
      "TV",
      admin.address
    );
  });

  it("应该允许用户存款", async function () {
    const depositAmount = ethers.utils.parseUnits("1000", 6);
    
    // 给用户铸造USDC
    await usdc.mint(user1.address, depositAmount);
    await usdc.connect(user1).approve(vault.address, depositAmount);
    
    // 存款
    const tx = await vault.connect(user1).deposit(depositAmount, user1.address);
    
    // 验证结果
    expect(await vault.balanceOf(user1.address)).to.equal(depositAmount);
    expect(await vault.totalAssets()).to.equal(depositAmount);
  });

  it("应该正确计算份额价值", async function () {
    // 测试逻辑...
  });
});
```

## 🔒 安全考虑

### 智能合约安全

#### 1. 重入攻击防护

```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SimpleVault is BaseVault, ReentrancyGuard {
    function deposit(uint256 assets, address receiver) 
        external 
        nonReentrant 
        returns (uint256 shares) 
    {
        // 存款逻辑...
    }
}
```

#### 2. 整数溢出防护

```solidity
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// 使用SafeMath进行安全的数学运算
using SafeMath for uint256;
using Math for uint256;
```

#### 3. 访问控制

```solidity
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SimpleVault is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Not admin");
        _;
    }
}
```

### 审计检查清单

- [ ] **重入攻击防护** - 所有外部调用使用重入保护
- [ ] **整数溢出检查** - 使用SafeMath或0.8.0+版本
- [ ] **权限验证** - 关键函数有适当的权限检查
- [ ] **紧急停止机制** - 实现紧急暂停功能
- [ ] **滑点保护** - 交易包含滑点参数
- [ ] **时间戳依赖** - 避免依赖block.timestamp做关键决策
- [ ] **外部调用安全** - 检查外部合约调用的返回值

## 📊 Gas 优化

### 优化技巧

1. **批量操作**
```solidity
// 批量存款，减少交易次数
function batchDeposit(uint256[] memory amounts, address[] memory receivers) external {
    for (uint i = 0; i < amounts.length; i++) {
        _deposit(amounts[i], receivers[i]);
    }
}
```

2. **存储优化**
```solidity
// 使用struct打包存储
struct VaultInfo {
    uint128 totalAssets;    // 16 bytes
    uint128 totalShares;    // 16 bytes
    uint64 lastHarvest;     // 8 bytes
    uint32 managementFee;   // 4 bytes
    uint32 performanceFee;  // 4 bytes
    bool stopped;           // 1 byte
    // 总计: 49 bytes (适合2个storage slot)
}
```

3. **事件优化**
```solidity
// 使用indexed参数进行高效过滤
event Deposit(
    address indexed sender,
    address indexed receiver,
    uint256 assets,
    uint256 shares
);
```

### Gas 报告

运行Gas报告来分析合约的Gas消耗：

```bash
npm run test:gas
```

预期Gas消耗：

| 函数 | Gas消耗 | 说明 |
|------|---------|------|
| deposit() | ~150,000 | 首次存款(包含策略投资) |
| withdraw() | ~120,000 | 取款(包含策略撤资) |
| harvest() | ~200,000 | 收益收获 |
| setStrategy() | ~50,000 | 策略设置 |

## 🌍 多链支持

### 支持的区块链网络

| 网络 | Chain ID | RPC URL | 区块浏览器 |
|------|----------|---------|------------|
| Ethereum Mainnet | 1 | https://mainnet.infura.io/v3/... | https://etherscan.io |
| Polygon | 137 | https://polygon-rpc.com | https://polygonscan.com |
| Arbitrum | 42161 | https://arb1.arbitrum.io/rpc | https://arbiscan.io |
| Optimism | 10 | https://mainnet.optimism.io | https://optimistic.etherscan.io |

### 跨链部署

```bash
# 部署到Polygon
npx hardhat run scripts/deploy.js --network polygon

# 部署到Arbitrum
npx hardhat run scripts/deploy.js --network arbitrum

# 部署到Optimism
npx hardhat run scripts/deploy.js --network optimism
```

## 📈 监控和分析

### 事件监听

```javascript
// 监听存款事件
vault.on("Deposit", (sender, owner, assets, shares, event) => {
    console.log(`存款事件: ${sender} 存入 ${ethers.utils.formatUnits(assets, 6)} USDC，获得 ${ethers.utils.formatEther(shares)} 份额`);
});

// 监听收获事件
vault.on("Harvest", (harvestedAmount, timestamp, event) => {
    console.log(`收获事件: 收获 ${ethers.utils.formatUnits(harvestedAmount, 6)} USDC 收益`);
});
```

### 数据分析查询

```javascript
// 获取资金库统计数据
async function getVaultStats(vaultAddress) {
    const vault = await ethers.getContractAt("SimpleVault", vaultAddress);
    
    const totalAssets = await vault.totalAssets();
    const totalSupply = await vault.totalSupply();
    const apy = await vault.getAPY();
    const strategy = await vault.activeStrategy();
    
    return {
        totalAssets: ethers.utils.formatUnits(totalAssets, 6),
        totalSupply: ethers.utils.formatEther(totalSupply),
        sharePrice: totalSupply.gt(0) ? totalAssets.mul(1e18).div(totalSupply) : ethers.utils.parseEther("1"),
        apy: ethers.utils.formatUnits(apy, 16), // APY percentage
        strategy: strategy
    };
}
```

## 🛠️ 开发工具

### 有用的NPM脚本

```json
{
  "scripts": {
    "compile": "hardhat compile",
    "test": "hardhat test",
    "test:coverage": "hardhat coverage",
    "test:gas": "REPORT_GAS=true hardhat test",
    "deploy:local": "hardhat run scripts/deploy.js --network localhost",
    "deploy:testnet": "hardhat run scripts/deploy.js --network testnet",
    "verify": "hardhat verify",
    "size": "hardhat size-contracts",
    "lint": "solhint 'src/**/*.sol'",
    "lint:fix": "solhint 'src/**/*.sol' --fix",
    "format": "prettier --write 'src/**/*.sol'"
  }
}
```

### Hardhat插件

- **@nomicfoundation/hardhat-toolbox** - 完整工具集
- **@openzeppelin/hardhat-upgrades** - 可升级合约
- **hardhat-gas-reporter** - Gas消耗报告
- **hardhat-contract-sizer** - 合约大小检查
- **solidity-coverage** - 代码覆盖率

## 🤝 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/NewStrategy`)
3. 编写测试用例
4. 提交更改 (`git commit -m 'Add new yield strategy'`)
5. 推送到分支 (`git push origin feature/NewStrategy`)
6. 开启 Pull Request

### 代码规范

- 使用 **Solidity 0.8.20**
- 遵循 **OpenZeppelin** 安全标准
- 所有公共函数必须有 **NatSpec** 文档
- 保持 **100%** 测试覆盖率
- 使用 **Prettier** 格式化代码

## 📞 联系方式和支持

- **项目维护者**: [@chspring1](https://github.com/chspring1)
- **合约仓库**: [MYA Platform Contracts](https://github.com/chspring1/mya-platform)
- **文档**: [智能合约文档](https://docs.mya-platform.com)
- **社区**: [Discord社区](https://discord.gg/mya-platform)

## 📄 许可证

本项目使用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## ⚠️ 免责声明

- 本合约系统仍在开发中，未经正式审计
- 不要在主网使用未经审计的代码
- DeFi投资存在风险，可能导致资金损失
- 在投资前请充分了解相关风险

---

> **重要提醒**: 这些智能合约仅用于教育和演示目的。在生产环境中使用前，请确保进行专业的安全审计。
