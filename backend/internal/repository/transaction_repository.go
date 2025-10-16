package repository

import (
	"fmt"

	"github.com/chspring1/mya-platform/backend/internal/models"
	"github.com/chspring1/mya-platform/backend/pkg/database"
	"github.com/chspring1/mya-platform/backend/pkg/logger"

	"gorm.io/gorm"
)

type TransactionRepository struct {
	db *gorm.DB
}

func NewTransactionRepository() *TransactionRepository {
	return &TransactionRepository{
		db: database.GetDB(),
	}
}

// Create 创建交易记录
func (r *TransactionRepository) Create(transaction *models.Transaction) error {
	result := r.db.Create(transaction)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to create transaction: %v", result.Error))
		return result.Error
	}
	return nil
}

// GetByTxHash 根据交易哈希获取交易
func (r *TransactionRepository) GetByTxHash(txHash string) (*models.Transaction, error) {
	var transaction models.Transaction
	result := r.db.Where("tx_hash = ?", txHash).First(&transaction)
	if result.Error != nil {
		if result.Error == gorm.ErrRecordNotFound {
			return nil, nil
		}
		logger.Error(fmt.Sprintf("Failed to get transaction by hash %s: %v", txHash, result.Error))
		return nil, result.Error
	}
	return &transaction, nil
}

// GetUserTransactions 获取用户的交易记录
func (r *TransactionRepository) GetUserTransactions(userAddress string, limit int) ([]models.Transaction, error) {
	var transactions []models.Transaction
	result := r.db.Where("user_address = ?", userAddress).Order("created_at DESC").Limit(limit).Find(&transactions)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to get user transactions: %v", result.Error))
		return nil, result.Error
	}
	return transactions, nil
}

// GetVaultTransactions 获取资金库的交易记录
func (r *TransactionRepository) GetVaultTransactions(vaultAddress string, limit int) ([]models.Transaction, error) {
	var transactions []models.Transaction
	result := r.db.Where("vault_address = ?", vaultAddress).Order("created_at DESC").Limit(limit).Find(&transactions)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to get vault transactions: %v", result.Error))
		return nil, result.Error
	}
	return transactions, nil
}

// UpdateStatus 更新交易状态
func (r *TransactionRepository) UpdateStatus(txHash string, status string) error {
	result := r.db.Model(&models.Transaction{}).Where("tx_hash = ?", txHash).Update("status", status)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to update transaction status: %v", result.Error))
		return result.Error
	}
	return nil
}
