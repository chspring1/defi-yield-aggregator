-- MYA Platform Database Initialization Script
-- 创建数据库和表结构

-- 切换到 mya_platform 数据库
\c mya_platform;

-- 创建用户表
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    address VARCHAR(42) UNIQUE NOT NULL,
    total_tvl DECIMAL(18,6) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 创建金库表
CREATE TABLE IF NOT EXISTS vaults (
    id SERIAL PRIMARY KEY,
    address VARCHAR(42) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    chain_id INTEGER NOT NULL,
    asset_address VARCHAR(42) NOT NULL,
    strategy_address VARCHAR(42),
    tvl DECIMAL(18,6) DEFAULT 0,
    apy_current DECIMAL(8,6) DEFAULT 0,
    apy_weekly DECIMAL(8,6) DEFAULT 0,
    total_deposits DECIMAL(18,6) DEFAULT 0,
    total_withdrawals DECIMAL(18,6) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 创建策略表
CREATE TABLE IF NOT EXISTS strategies (
    id SERIAL PRIMARY KEY,
    address VARCHAR(42) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    vault_address VARCHAR(42) NOT NULL,
    apy DECIMAL(8,6) DEFAULT 0,
    risk_score SMALLINT DEFAULT 0,
    total_assets DECIMAL(18,6) DEFAULT 0,
    total_earnings DECIMAL(18,6) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    last_harvest TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 创建交易表
CREATE TABLE IF NOT EXISTS transactions (
    id SERIAL PRIMARY KEY,
    user_address VARCHAR(42) NOT NULL,
    vault_address VARCHAR(42) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('deposit', 'withdraw')),
    amount DECIMAL(18,6) NOT NULL,
    shares DECIMAL(18,6) DEFAULT 0,
    tx_hash VARCHAR(66) UNIQUE NOT NULL,
    block_number BIGINT,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'failed')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_users_address ON users(address);
CREATE INDEX IF NOT EXISTS idx_vaults_address ON vaults(address);
CREATE INDEX IF NOT EXISTS idx_vaults_is_active ON vaults(is_active);
CREATE INDEX IF NOT EXISTS idx_strategies_address ON strategies(address);
CREATE INDEX IF NOT EXISTS idx_strategies_vault_address ON strategies(vault_address);
CREATE INDEX IF NOT EXISTS idx_transactions_user_address ON transactions(user_address);
CREATE INDEX IF NOT EXISTS idx_transactions_vault_address ON transactions(vault_address);
CREATE INDEX IF NOT EXISTS idx_transactions_tx_hash ON transactions(tx_hash);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);

-- 插入示例数据
INSERT INTO users (address, total_tvl) VALUES
    ('0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d', 25000.00),
    ('0xAdminAddress', 0.00)
ON CONFLICT (address) DO NOTHING;

INSERT INTO vaults (address, name, symbol, chain_id, asset_address, strategy_address, tvl, apy_current, apy_weekly, total_deposits, total_withdrawals, is_active) VALUES
    ('0xVault1', 'USDC Yield Vault', 'myaUSDC', 1, '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', '0xStrategy1', 1000000.00, 0.0525, 0.0521, 1500000.00, 500000.00, true),
    ('0xVault2', 'ETH Staking Vault', 'myaETH', 1, '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', '0xStrategy2', 500000.00, 0.0420, 0.0415, 750000.00, 250000.00, true)
ON CONFLICT (address) DO NOTHING;

INSERT INTO strategies (address, name, vault_address, apy, risk_score, total_assets, total_earnings, is_active, last_harvest) VALUES
    ('0xStrategy1', 'AAVE Lending Strategy', '0xVault1', 0.0480, 2, 950000.00, 45600.00, true, CURRENT_TIMESTAMP - INTERVAL '2 hours'),
    ('0xStrategy2', 'Compound Supply Strategy', '0xVault1', 0.0450, 2, 50000.00, 2275.00, true, CURRENT_TIMESTAMP - INTERVAL '1 hour')
ON CONFLICT (address) DO NOTHING;

INSERT INTO transactions (user_address, vault_address, type, amount, shares, tx_hash, block_number, status) VALUES
    ('0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d', '0xVault1', 'deposit', 25000.00, 25000.000000, '0xTxHash123456789abcdef', 18500000, 'confirmed'),
    ('0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d', '0xVault2', 'deposit', 1500.00, 1.500000, '0xTxHash987654321fedcba', 18500001, 'confirmed')
ON CONFLICT (tx_hash) DO NOTHING;

-- 创建触发器函数来自动更新 updated_at 字段
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为需要的表创建触发器
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_vaults_updated_at ON vaults;
CREATE TRIGGER update_vaults_updated_at
    BEFORE UPDATE ON vaults
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_strategies_updated_at ON strategies;
CREATE TRIGGER update_strategies_updated_at
    BEFORE UPDATE ON strategies
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 显示创建的表
\dt

-- 显示用户表数据
SELECT 'Users table:' AS info;
SELECT * FROM users;

-- 显示金库表数据
SELECT 'Vaults table:' AS info;
SELECT * FROM vaults;

-- 显示策略表数据
SELECT 'Strategies table:' AS info;
SELECT * FROM strategies;

-- 显示交易表数据
SELECT 'Transactions table:' AS info;
SELECT * FROM transactions;

PRINT 'Database initialization completed successfully!';