package service

import (
	"fmt"

	"github.com/chspring1/mya-platform/backend/internal/models"
	"github.com/chspring1/mya-platform/backend/internal/repository"
	"github.com/chspring1/mya-platform/backend/pkg/logger"
)

type VaultService struct {
	vaultRepo *repository.VaultRepository
}

func NewVaultService() *VaultService {
	return &VaultService{
		vaultRepo: repository.NewVaultRepository(),
	}
}

// GetVaults 获取所有资金库
func (s *VaultService) GetVaults() ([]models.Vault, error) {
	vaults, err := s.vaultRepo.ListAll()
	if err != nil {
		logger.Error(fmt.Sprintf("Failed to get vaults: %v", err))
		return nil, err
	}
	return vaults, nil
}

// GetVaultDetail 获取资金库详情
func (s *VaultService) GetVaultDetail(address string) (*models.Vault, error) {
	vault, err := s.vaultRepo.GetByAddress(address)
	if err != nil {
		logger.Error(fmt.Sprintf("Failed to get vault detail for %s: %v", address, err))
		return nil, err
	}

	if vault == nil {
		return nil, nil
	}

	return vault, nil
}

// GetActiveVaults 获取活跃的资金库
func (s *VaultService) GetActiveVaults() ([]models.Vault, error) {
	vaults, err := s.vaultRepo.GetActiveVaults()
	if err != nil {
		logger.Error(fmt.Sprintf("Failed to get active vaults: %v", err))
		return nil, err
	}
	return vaults, nil
}

// UpdateVaultStats 更新资金库统计信息
func (s *VaultService) UpdateVaultStats(address string, tvl, apyCurrent, apyWeekly float64) error {
	if err := s.vaultRepo.UpdateTVL(address, tvl); err != nil {
		return err
	}

	if err := s.vaultRepo.UpdateAPY(address, apyCurrent, apyWeekly); err != nil {
		return err
	}

	return nil
}
