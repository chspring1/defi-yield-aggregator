package repository

import (
	"fmt"

	"github.com/chspring1/mya-platform/backend/internal/models"
	"github.com/chspring1/mya-platform/backend/pkg/database"
	"github.com/chspring1/mya-platform/backend/pkg/logger"

	"gorm.io/gorm"
)

type UserRepository struct {
	db *gorm.DB
}

func NewUserRepository() *UserRepository {
	return &UserRepository{
		db: database.GetDB(),
	}
}

// Create 创建用户
func (r *UserRepository) Create(user *models.User) error {
	result := r.db.Create(user)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to create user: %v", result.Error))
		return result.Error
	}
	return nil
}

// GetByAddress 根据地址获取用户
func (r *UserRepository) GetByAddress(address string) (*models.User, error) {
	var user models.User
	result := r.db.Where("address = ?", address).First(&user)
	if result.Error != nil {
		if result.Error == gorm.ErrRecordNotFound {
			return nil, nil
		}
		logger.Error(fmt.Sprintf("Failed to get user by address %s: %v", address, result.Error))
		return nil, result.Error
	}
	return &user, nil
}

// GetOrCreate 获取或创建用户
func (r *UserRepository) GetOrCreate(address string) (*models.User, error) {
	user, err := r.GetByAddress(address)
	if err != nil {
		return nil, err
	}

	if user == nil {
		user = &models.User{
			Address:  address,
			TotalTVL: 0,
		}
		if err := r.Create(user); err != nil {
			return nil, err
		}
	}

	return user, nil
}

// UpdateTVL 更新用户总TVL
func (r *UserRepository) UpdateTVL(address string, tvl float64) error {
	result := r.db.Model(&models.User{}).Where("address = ?", address).Update("total_tvl", tvl)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to update user TVL: %v", result.Error))
		return result.Error
	}
	return nil
}

// ListAll 获取所有用户
func (r *UserRepository) ListAll() ([]models.User, error) {
	var users []models.User
	result := r.db.Find(&users)
	if result.Error != nil {
		logger.Error(fmt.Sprintf("Failed to list users: %v", result.Error))
		return nil, result.Error
	}
	return users, nil
}
