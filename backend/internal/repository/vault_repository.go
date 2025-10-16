package repository

import (
	"fmt"

	"github.com/chspring1/mya-platform/backend/internal/models"
	"github.com/chspring1/mya-platform/backend/pkg/database"
	"github.com/chspring1/mya-platform/backend/pkg/logger"

	"gorm.io/gorm"
)

type VaultRepository struct {
	db *gorm.DB
}

func NewVaultRepository() *VaultRepository {
	return &VaultRepository{
		db: database.GetDB(),
	}
}

// Create 创建资金库
func (r *VaultRepository) Create(vault *models.Vault) error {
	result := r.db.Create(vault)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to create vault: %v", result.Error))
		return result.Error
	}
	return nil
}

// GetByAddress 根据地址获取资金库
func (r *VaultRepository) GetByAddress(address string) (*models.Vault, error) {
	var vault models.Vault
	result := r.db.Preload("Strategies").Where("address = ?", address).First(&vault)
	if result.Error != nil {
		if result.Error == gorm.ErrRecordNotFound {
			return nil, nil
		}
		logger.Error(fmt.Sprintf("Failed to get vault by address %s: %v", address, result.Error))
		return nil, result.Error
	}
	return &vault, nil
}

// ListAll 获取所有资金库
func (r *VaultRepository) ListAll() ([]models.Vault, error) {
	var vaults []models.Vault
	result := r.db.Preload("Strategies").Where("is_active = ?", true).Find(&vaults)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to list vaults: %v", result.Error))
		return nil, result.Error
	}
	return vaults, nil
}

// UpdateTVL 更新资金库TVL
func (r *VaultRepository) UpdateTVL(address string, tvl float64) error {
	result := r.db.Model(&models.Vault{}).Where("address = ?", address).Update("tvl", tvl)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to update vault TVL: %v", result.Error))
		return result.Error
	}
	return nil
}

// UpdateAPY 更新资金库APY
func (r *VaultRepository) UpdateAPY(address string, apyCurrent, apyWeekly float64) error {
	result := r.db.Model(&models.Vault{}).Where("address = ?", address).Updates(map[string]interface{}{
		"apy_current": apyCurrent,
		"apy_weekly":  apyWeekly,
	})
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to update vault APY: %v", result.Error))
		return result.Error
	}
	return nil
}

// GetActiveVaults 获取活跃的资金库
func (r *VaultRepository) GetActiveVaults() ([]models.Vault, error) {
	var vaults []models.Vault
	result := r.db.Preload("Strategies", "is_active = ?", true).Where("is_active = ?", true).Find(&vaults)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to get active vaults: %v", result.Error))
		return nil, result.Error
	}
	return vaults, nil
}
