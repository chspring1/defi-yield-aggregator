package repository

import (
	"fmt"
	"time"

	"github.com/chspring1/mya-platform/backend/internal/models"
	"github.com/chspring1/mya-platform/backend/pkg/database"
	"github.com/chspring1/mya-platform/backend/pkg/logger"

	"gorm.io/gorm"
)

type StrategyRepository struct {
	db *gorm.DB
}

func NewStrategyRepository() *StrategyRepository {
	return &StrategyRepository{
		db: database.GetDB(),
	}
}

// Create 创建策略
func (r *StrategyRepository) Create(strategy *models.Strategy) error {
	result := r.db.Create(strategy)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to create strategy: %v", result.Error))
		return result.Error
	}
	return nil
}

// GetByAddress 根据地址获取策略
func (r *StrategyRepository) GetByAddress(address string) (*models.Strategy, error) {
	var strategy models.Strategy
	result := r.db.Where("address = ?", address).First(&strategy)
	if result.Error != nil {
		if result.Error == gorm.ErrRecordNotFound {
			return nil, nil
		}
		logger.Error(fmt.Sprintf("Failed to get strategy by address %s: %v", address, result.Error))
		return nil, result.Error
	}
	return &strategy, nil
}

// GetByVault 获取资金库的所有策略
func (r *StrategyRepository) GetByVault(vaultAddress string) ([]models.Strategy, error) {
	var strategies []models.Strategy
	result := r.db.Where("vault_address = ? AND is_active = ?", vaultAddress, true).Find(&strategies)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to get strategies for vault %s: %v", vaultAddress, result.Error))
		return nil, result.Error
	}
	return strategies, nil
}

// UpdateAPY 更新策略APY
func (r *StrategyRepository) UpdateAPY(address string, apy float64) error {
	result := r.db.Model(&models.Strategy{}).Where("address = ?", address).Update("apy", apy)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to update strategy APY: %v", result.Error))
		return result.Error
	}
	return nil
}

// UpdateAssets 更新策略总资产
func (r *StrategyRepository) UpdateAssets(address string, totalAssets float64) error {
	result := r.db.Model(&models.Strategy{}).Where("address = ?", address).Update("total_assets", totalAssets)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to update strategy assets: %v", result.Error))
		return result.Error
	}
	return nil
}

// RecordHarvest 记录收获事件
func (r *StrategyRepository) RecordHarvest(address string, earnings float64) error {
	now := time.Now()
	result := r.db.Model(&models.Strategy{}).Where("address = ?", address).Updates(map[string]interface{}{
		"total_earnings": gorm.Expr("total_earnings + ?", earnings),
		"last_harvest":   now,
	})
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to record harvest: %v", result.Error))
		return result.Error
	}
	return nil
}
