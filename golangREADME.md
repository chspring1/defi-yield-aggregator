# MYA Platform - DeFi 收益聚合平台

[![Go Version](https://img.shields.io/badge/Go-1.21+-blue.svg)](https://golang.org)
[![Gin Framework](https://img.shields.io/badge/Gin-1.9+-green.svg)](https://gin-gonic.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-blue.svg)](https://postgresql.org)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📖 项目简介

MYA Platform 是一个去中心化金融(DeFi)收益聚合平台，提供多链资产管理、智能投资策略和风险控制功能。该平台通过智能合约和后端服务，为用户提供安全、高效的 DeFi 投资体验。

## 🏗️ 项目架构

```
mya-platform/
├── backend/           # Go 后端服务
│   ├── cmd/          # 应用程序入口
│   ├── internal/     # 内部包
│   │   ├── api/      # API 相关代码
│   │   └── models/   # 数据模型
│   ├── pkg/          # 公共包
│   │   ├── config/   # 配置管理
│   │   ├── database/ # 数据库连接
│   │   └── logger/   # 日志管理
│   └── migrations/   # 数据库迁移
├── contracts/        # 智能合约
├── frontend/         # 前端应用
├── configs/          # 配置文件
├── docs/            # 文档
└── scripts/         # 部署脚本
```

## 🚀 技术栈

### 后端技术
- **Go 1.21+** - 主要编程语言
- **Gin** - Web 框架
- **GORM** - ORM 框架
- **PostgreSQL** - 主数据库
- **Redis** - 缓存和会话存储
- **Kafka** - 消息队列
- **Docker** - 容器化部署

### 区块链技术
- **Solidity** - 智能合约开发
- **Hardhat** - 合约开发框架
- **OpenZeppelin** - 安全合约库
- **Web3** - 区块链交互

### 前端技术
- **React** - 前端框架
- **TypeScript** - 类型安全
- **Web3.js/Ethers.js** - 区块链交互

## 📚 数据模型

### 用户模型 (User)
```go
type User struct {
    ID        uint      `json:"id"`
    Address   string    `json:"address"`     // 以太坊地址
    TotalTVL  float64   `json:"total_tvl"`   // 总锁定价值
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}
```

### 资金库模型 (Vault)
```go
type Vault struct {
    ID              uint      `json:"id"`
    Address         string    `json:"address"`          // 合约地址
    Name            string    `json:"name"`             // 名称
    Symbol          string    `json:"symbol"`           // 代币符号
    ChainID         uint      `json:"chain_id"`         // 链ID
    AssetAddress    string    `json:"asset_address"`    // 底层资产地址
    StrategyAddress string    `json:"strategy_address"` // 策略地址
    TVL             float64   `json:"tvl"`              // 总锁定价值
    APYCurrent      float64   `json:"apy_current"`      // 当前年化收益率
    APYWeekly       float64   `json:"apy_weekly"`       // 周年化收益率
    TotalDeposits   float64   `json:"total_deposits"`   // 总存款
    TotalWithdrawals float64  `json:"total_withdrawals"` // 总提款
    IsActive        bool      `json:"is_active"`        // 是否活跃
    CreatedAt       time.Time `json:"created_at"`
    UpdatedAt       time.Time `json:"updated_at"`
}
```

### 策略模型 (Strategy)
```go
type Strategy struct {
    ID            uint      `json:"id"`
    Address       string    `json:"address"`        // 策略合约地址
    Name          string    `json:"name"`           // 策略名称
    VaultAddress  string    `json:"vault_address"`  // 关联资金库
    APY           float64   `json:"apy"`            // 年化收益率
    RiskScore     uint8     `json:"risk_score"`     // 风险评分(1-10)
    TotalAssets   float64   `json:"total_assets"`   // 总资产
    TotalEarnings float64   `json:"total_earnings"` // 总收益
    IsActive      bool      `json:"is_active"`      // 是否活跃
    LastHarvest   *time.Time `json:"last_harvest"`  // 最后一次收割时间
    CreatedAt     time.Time `json:"created_at"`
    UpdatedAt     time.Time `json:"updated_at"`
}
```

### 交易模型 (Transaction)
```go
type Transaction struct {
    ID           uint      `json:"id"`
    UserAddress  string    `json:"user_address"`  // 用户地址
    VaultAddress string    `json:"vault_address"` // 资金库地址
    Type         string    `json:"type"`          // 交易类型: deposit, withdraw
    Amount       float64   `json:"amount"`        // 交易金额
    Shares       float64   `json:"shares"`        // 份额
    TxHash       string    `json:"tx_hash"`       // 交易哈希
    BlockNumber  uint64    `json:"block_number"`  // 区块号
    Status       string    `json:"status"`        // 状态: pending, confirmed, failed
    CreatedAt    time.Time `json:"created_at"`
}
```

## 🔌 API 接口文档

### 认证方式

所有需要认证的接口都需要在请求头中包含用户的以太坊地址：

```http
X-User-Address: 0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d
```

### 公开接口 (无需认证)

#### 1. 健康检查

```http
GET /health
```

**响应示例:**
```json
{
  "status": "healthy",
  "service": "mya-platform-api",
  "framework": "gin",
  "version": "1.0.0"
}
```

---

#### 2. 获取所有资金库

```http
GET /api/v1/vaults
```

**响应示例:**
```json
{
  "vaults": [
    {
      "address": "0xVault1",
      "name": "USDC Yield Vault",
      "tvl": "1000000.00",
      "apy": "0.0525",
      "chain": "Ethereum",
      "asset": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    },
    {
      "address": "0xVault2",
      "name": "ETH Staking Vault",
      "tvl": "500000.00",
      "apy": "0.0420",
      "chain": "Ethereum",
      "asset": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    }
  ]
}
```

---

#### 3. 获取资金库详情

```http
GET /api/v1/vaults/{address}
```

**路径参数:**
- `address` (string): 资金库合约地址

**响应示例:**
```json
{
  "vault": {
    "address": "0xVault1",
    "name": "USDC Yield Vault",
    "tvl": "1000000.00",
    "apy": "0.0525",
    "strategy": "0xStrategy1",
    "asset": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    "total_deposits": "1500000.00",
    "total_withdrawals": "500000.00",
    "created": "2024-01-01T00:00:00Z",
    "is_active": true
  }
}
```

---

#### 4. 获取所有策略

```http
GET /api/v1/strategies
```

**响应示例:**
```json
{
  "strategies": [
    {
      "address": "0xStrategy1",
      "name": "AAVE Lending Strategy",
      "vault": "0xVault1",
      "apy": "0.0480",
      "risk_score": 2,
      "total_assets": "950000.00",
      "is_active": true
    },
    {
      "address": "0xStrategy2",
      "name": "Compound Supply Strategy",
      "vault": "0xVault1",
      "apy": "0.0450",
      "risk_score": 2,
      "total_assets": "50000.00",
      "is_active": true
    }
  ]
}
```

---

#### 5. 获取APY数据

```http
GET /api/v1/apy
```

**响应示例:**
```json
{
  "apy_data": [
    {
      "vault": "0xVault1",
      "apy_7d": "0.0521",
      "apy_30d": "0.0518",
      "apy_90d": "0.0505"
    },
    {
      "vault": "0xVault2",
      "apy_7d": "0.0415",
      "apy_30d": "0.0422",
      "apy_90d": "0.0410"
    }
  ]
}
```

### 需要认证的接口

#### 6. 获取用户信息

```http
GET /api/v1/users/{address}
```

**请求头:**
```http
X-User-Address: 0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d
```

**路径参数:**
- `address` (string): 用户以太坊地址

**响应示例:**
```json
{
  "user": {
    "address": "0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d",
    "total_tvl": "25000.00",
    "total_apy": "0.0495",
    "joined_at": "2024-01-15T00:00:00Z",
    "vault_count": 2
  }
}
```

---

#### 7. 获取用户持仓

```http
GET /api/v1/users/{address}/positions
```

**请求头:**
```http
X-User-Address: 0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d
```

**路径参数:**
- `address` (string): 用户以太坊地址

**响应示例:**
```json
{
  "user_address": "0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d",
  "positions": [
    {
      "vault_address": "0xVault1",
      "vault_name": "USDC Yield Vault",
      "shares": "25000.000000",
      "assets": "25625.000000",
      "apy": "0.0525",
      "value_usd": "25625.00"
    },
    {
      "vault_address": "0xVault2",
      "vault_name": "ETH Staking Vault",
      "shares": "1.500000",
      "assets": "1.530000",
      "apy": "0.0420",
      "value_usd": "2800.00"
    }
  ]
}
```

---

#### 8. 存款到资金库

```http
POST /api/v1/vaults/{address}/deposit
```

**请求头:**
```http
X-User-Address: 0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d
Content-Type: application/json
```

**路径参数:**
- `address` (string): 资金库合约地址

**请求体:**
```json
{
  "amount": "1000.00",
  "slippage": "0.005"
}
```

**响应示例:**
```json
{
  "transaction": {
    "hash": "0xTxHash123",
    "status": "pending",
    "vault": "0xVault1",
    "user": "0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d",
    "amount": "1000.00",
    "type": "deposit"
  }
}
```

---

#### 9. 从资金库提款

```http
POST /api/v1/vaults/{address}/withdraw
```

**请求头:**
```http
X-User-Address: 0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d
Content-Type: application/json
```

**路径参数:**
- `address` (string): 资金库合约地址

**请求体:**
```json
{
  "shares": "500.00",
  "slippage": "0.005"
}
```

**响应示例:**
```json
{
  "transaction": {
    "hash": "0xTxHash456",
    "status": "pending",
    "vault": "0xVault1",
    "user": "0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d",
    "amount": "500.00",
    "type": "withdraw"
  }
}
```

### 管理员接口 (需要管理员权限)

#### 10. 获取系统统计

```http
GET /api/v1/admin/stats
```

**请求头:**
```http
X-User-Address: 0xAdminAddress
```

**响应示例:**
```json
{
  "stats": {
    "total_tvl": "1500000.00",
    "total_users": 125,
    "total_vaults": 3,
    "total_strategies": 5,
    "total_deposits": "2500000.00",
    "total_withdrawals": "1000000.00",
    "total_yield": "75000.00",
    "avg_apy": "0.0485",
    "updated_at": "2024-01-20T12:00:00Z"
  }
}
```

---

#### 11. 紧急停止资金库

```http
POST /api/v1/admin/vaults/{address}/emergency-stop
```

**请求头:**
```http
X-User-Address: 0xAdminAddress
```

**路径参数:**
- `address` (string): 资金库合约地址

**响应示例:**
```json
{
  "action": "emergency_stop",
  "vault": "0xVault1",
  "status": "stopped",
  "message": "Vault has been emergency stopped"
}
```

---

#### 12. 获取监控数据

```http
GET /api/v1/admin/monitoring
```

**请求头:**
```http
X-User-Address: 0xAdminAddress
```

**响应示例:**
```json
{
  "monitoring": {
    "active_connections": 45,
    "request_per_minute": 120,
    "error_rate": "0.02",
    "response_time_avg": "45ms",
    "database_connections": 12,
    "last_updated": "2024-01-20T12:00:00Z"
  }
}
```

## 🛡️ 中间件功能

### 1. 认证中间件 (AuthRequired)
- 验证 `X-User-Address` 请求头
- 校验以太坊地址格式
- 将用户地址存储到上下文中

### 2. 管理员中间件 (AdminRequired)
- 检查用户是否为管理员
- 基于预设的管理员地址列表

### 3. 安全中间件 (Security)
- 设置安全响应头
- 防止XSS攻击
- 配置CORS策略

### 4. 速率限制中间件 (RateLimit)
- 每分钟60次请求限制
- 基于客户端IP地址
- 返回限制相关的响应头

### 5. 日志中间件 (Logger)
- 记录所有HTTP请求
- 包含请求方法、路径、状态码、响应时间

## 🔧 配置说明

### 环境配置

项目支持多环境配置，通过 `configs/config.yaml` 文件进行配置：

```yaml
server:
  port: "8080"              # 服务端口
  mode: "debug"             # 运行模式: debug, release
  read_timeout: 30          # 读取超时(秒)
  write_timeout: 30         # 写入超时(秒)

database:
  host: "localhost"         # 数据库主机
  port: "5432"             # 数据库端口
  user: "mya_user"         # 数据库用户名
  password: "mya_password" # 数据库密码
  dbname: "mya_platform"   # 数据库名称
  sslmode: "disable"       # SSL模式

redis:
  host: "localhost"        # Redis主机
  port: "6379"            # Redis端口
  password: ""            # Redis密码
  db: 0                   # Redis数据库

blockchain:
  ethereum_rpc: "https://eth.llamarpc.com"  # 以太坊RPC节点
  chain_id: 1                               # 链ID

auth:
  jwt_secret: "your-secret-key"            # JWT密钥
  jwt_duration: 24                         # JWT有效期(小时)
```

## 🚀 部署指南

### 环境要求

- Go 1.21+
- PostgreSQL 15+
- Redis 6+
- Docker & Docker Compose

### 本地开发

1. **克隆项目**
```bash
git clone https://github.com/chspring1/mya-platform.git
cd mya-platform
```

2. **安装依赖**
```bash
cd backend
go mod download
```

3. **启动数据库**
```bash
docker-compose up -d postgres redis
```

4. **初始化数据库**
```bash
docker exec -i mya-postgres psql -U mya_user -d mya_platform < backend/migrations/init-db.sql
```

5. **启动服务**
```bash
cd backend
go run cmd/api-server/main.go
```

### Docker 部署

1. **构建镜像**
```bash
docker-compose build
```

2. **启动服务**
```bash
docker-compose up -d
```

### 生产部署

1. **使用 Docker Compose**
```bash
# 生产环境配置
cp configs/config.example.yaml configs/config.yaml
# 修改配置文件中的生产环境设置

# 启动服务
docker-compose -f docker-compose.prod.yml up -d
```

2. **Kubernetes 部署**
```bash
kubectl apply -f deployments/k8s/
```

## 🧪 测试

### 运行单元测试
```bash
cd backend
go test ./...
```

### 运行集成测试
```bash
cd backend
go test -tags=integration ./tests/integration/...
```

### API 测试示例

```bash
# 健康检查
curl http://localhost:8080/health

# 获取资金库列表
curl http://localhost:8080/api/v1/vaults

# 获取用户信息 (需要认证)
curl -H "X-User-Address: 0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d" \
     http://localhost:8080/api/v1/users/0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d

# 存款操作
curl -X POST \
     -H "X-User-Address: 0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d" \
     -H "Content-Type: application/json" \
     -d '{"amount":"1000.00","slippage":"0.005"}' \
     http://localhost:8080/api/v1/vaults/0xVault1/deposit
```

## 📊 监控和日志

### 日志级别
- **INFO**: 常规操作信息
- **ERROR**: 错误信息
- **DEBUG**: 调试信息

### 监控指标
- API 请求响应时间
- 数据库连接状态
- 系统资源使用情况
- 区块链交互状态

## 🔒 安全考虑

### 认证安全
- 当前使用简单的地址验证，生产环境建议使用数字签名验证
- 支持JWT令牌认证
- 实施速率限制防止滥用

### 数据安全
- 数据库连接使用SSL加密
- 敏感配置信息通过环境变量管理
- 定期备份数据库

### 智能合约安全
- 使用OpenZeppelin安全合约库
- 实施紧急停止机制
- 多重签名控制

## 🤝 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

该项目使用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 📞 联系方式

- 项目维护者: [@chspring1](https://github.com/chspring1)
- 项目链接: [https://github.com/chspring1/mya-platform](https://github.com/chspring1/mya-platform)

## 🙏 致谢

- [Gin](https://gin-gonic.com/) - Web框架
- [GORM](https://gorm.io/) - ORM框架
- [OpenZeppelin](https://openzeppelin.com/) - 智能合约库
- [Hardhat](https://hardhat.org/) - 以太坊开发环境

---

> **注意**: 这是一个演示项目。在生产环境中使用前，请确保进行充分的安全审计和测试。
