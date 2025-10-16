package main

import (
	"fmt"

	"github.com/chspring1/mya-platform/backend/internal/api/routes"
	"github.com/chspring1/mya-platform/backend/pkg/config"
	"github.com/chspring1/mya-platform/backend/pkg/database"
	"github.com/chspring1/mya-platform/backend/pkg/logger"
)

func main() {
	// 初始化配置
	cfg := config.Load()

	// 初始化日志
	logger.Init()
	logger.Info("🚀 Starting MYA Platform API Server")

	// 初始化数据库
	database.Init()

	// 设置并启动Gin服务器
	router := routes.SetupRouter()

	logger.Info(fmt.Sprintf("🌐 Server running on port %s", cfg.Server.Port))

	// 启动服务器
	router.Run(":" + cfg.Server.Port)
}
