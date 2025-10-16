package service

import (
	"fmt"

	"github.com/chspring1/mya-platform/backend/internal/models"
	"github.com/chspring1/mya-platform/backend/internal/repository"
	"github.com/chspring1/mya-platform/backend/pkg/logger"
)

type UserService struct {
	userRepo *repository.UserRepository
}

func NewUserService() *UserService {
	return &UserService{
		userRepo: repository.NewUserRepository(),
	}
}

// GetUserInfo 获取用户信息
func (s *UserService) GetUserInfo(address string) (*models.User, error) {
	user, err := s.userRepo.GetOrCreate(address)
	if err != nil {
		logger.Error(fmt.Sprintf("Failed to get user info for %s: %v", address, err))
		return nil, err
	}
	return user, nil
}

// UpdateUserTVL 更新用户总TVL
func (s *UserService) UpdateUserTVL(address string, tvl float64) error {
	if err := s.userRepo.UpdateTVL(address, tvl); err != nil {
		logger.Error(fmt.Sprintf("Failed to update user TVL: %v", err))
		return err
	}
	return nil
}
