package database

import (
	"fmt"

	"github.com/chspring1/mya-platform/backend/pkg/config"
	"github.com/chspring1/mya-platform/backend/pkg/logger"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

// Init 初始化数据库连接
func Init() {
	cfg := config.Load()

	// 构建数据库连接字符串
	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=disable",
		cfg.Database.Host,
		cfg.Database.User,
		cfg.Database.Password,
		cfg.Database.DBName,
		cfg.Database.Port,
	)

	logger.Info(fmt.Sprintf("Connecting to database: %s@%s:%s/%s",
		cfg.Database.User, cfg.Database.Host, cfg.Database.Port, cfg.Database.DBName))

	var err error
	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		logger.Error(fmt.Sprintf("Failed to connect to database: %v", err))
		return
	}

	logger.Info("✅ Database connection established")

	// 测试连接
	var version string
	DB.Raw("SELECT version()").Scan(&version)
	logger.Info("📊 Connected to PostgreSQL")

	// 检查表是否存在
	checkTables()
}

// checkTables 检查必要的表是否存在
func checkTables() {
	tables := []string{"users", "vaults", "strategies", "transactions"}

	for _, table := range tables {
		var exists bool
		DB.Raw("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = ?)", table).Scan(&exists)
		if exists {
			logger.Info(fmt.Sprintf("✅ Table %s exists", table))
		} else {
			logger.Info(fmt.Sprintf("❌ Table %s does not exist", table))
		}
	}
}

// GetDB 获取数据库连接
func GetDB() *gorm.DB {
	return DB
}

// Close 关闭数据库连接
func Close() error {
	sqlDB, err := DB.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}
