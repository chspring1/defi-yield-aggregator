package models

import (
	"time"

	"gorm.io/gorm"
)

// User 用户模型
type User struct {
	ID        uint           `gorm:"primaryKey" json:"id"`
	Address   string         `gorm:"uniqueIndex;size:42;not null" json:"address"`
	TotalTVL  float64        `gorm:"type:decimal(36,18);default:0" json:"total_tvl"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

// Vault 资金库模型
type Vault struct {
	ID               uint           `gorm:"primaryKey" json:"id"`
	Address          string         `gorm:"uniqueIndex;size:42;not null" json:"address"`
	Name             string         `gorm:"size:100;not null" json:"name"`
	Symbol           string         `gorm:"size:20;not null" json:"symbol"`
	ChainID          uint           `gorm:"not null" json:"chain_id"`
	AssetAddress     string         `gorm:"size:42;not null" json:"asset_address"`
	StrategyAddress  string         `gorm:"size:42" json:"strategy_address"`
	TVL              float64        `gorm:"type:decimal(36,18);default:0" json:"tvl"`
	APYCurrent       float64        `gorm:"type:decimal(10,8);default:0" json:"apy_current"`
	APYWeekly        float64        `gorm:"type:decimal(10,8);default:0" json:"apy_weekly"`
	TotalDeposits    float64        `gorm:"type:decimal(36,18);default:0" json:"total_deposits"`
	TotalWithdrawals float64        `gorm:"type:decimal(36,18);default:0" json:"total_withdrawals"`
	IsActive         bool           `gorm:"default:true" json:"is_active"`
	CreatedAt        time.Time      `json:"created_at"`
	UpdatedAt        time.Time      `json:"updated_at"`
	DeletedAt        gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联关系
	Strategies []Strategy `gorm:"foreignKey:VaultAddress;references:Address" json:"strategies,omitempty"`
}

// Strategy 策略模型
type Strategy struct {
	ID            uint           `gorm:"primaryKey" json:"id"`
	Address       string         `gorm:"uniqueIndex;size:42;not null" json:"address"`
	Name          string         `gorm:"size:100;not null" json:"name"`
	VaultAddress  string         `gorm:"size:42;not null" json:"vault_address"`
	APY           float64        `gorm:"type:decimal(10,8);default:0" json:"apy"`
	RiskScore     uint8          `gorm:"default:1" json:"risk_score"`
	TotalAssets   float64        `gorm:"type:decimal(36,18);default:0" json:"total_assets"`
	TotalEarnings float64        `gorm:"type:decimal(36,18);default:0" json:"total_earnings"`
	IsActive      bool           `gorm:"default:true" json:"is_active"`
	LastHarvest   *time.Time     `json:"last_harvest"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
}

// Transaction 交易模型
type Transaction struct {
	ID           uint           `gorm:"primaryKey" json:"id"`
	UserAddress  string         `gorm:"size:42;not null" json:"user_address"`
	VaultAddress string         `gorm:"size:42;not null" json:"vault_address"`
	Type         string         `gorm:"size:20;not null" json:"type"` // deposit, withdraw
	Amount       float64        `gorm:"type:decimal(36,18);not null" json:"amount"`
	Shares       float64        `gorm:"type:decimal(36,18);not null" json:"shares"`
	TxHash       string         `gorm:"uniqueIndex;size:66;not null" json:"tx_hash"`
	BlockNumber  uint64         `gorm:"not null" json:"block_number"`
	Status       string         `gorm:"size:20;default:pending" json:"status"` // pending, confirmed, failed
	CreatedAt    time.Time      `json:"created_at"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

// APYHistory APY历史记录模型
type APYHistory struct {
	ID           uint      `gorm:"primaryKey" json:"id"`
	VaultAddress string    `gorm:"size:42;not null" json:"vault_address"`
	APYValue     float64   `gorm:"type:decimal(10,8);not null" json:"apy_value"`
	TVL          float64   `gorm:"type:decimal(36,18);not null" json:"tvl"`
	Timestamp    time.Time `gorm:"default:CURRENT_TIMESTAMP" json:"timestamp"`
}

// 表名映射
func (User) TableName() string {
	return "users"
}

func (Vault) TableName() string {
	return "vaults"
}

func (Strategy) TableName() string {
	return "strategies"
}

func (Transaction) TableName() string {
	return "transactions"
}

func (APYHistory) TableName() string {
	return "apy_history"
}
