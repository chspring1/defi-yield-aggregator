package routes

import (
	"github.com/chspring1/mya-platform/backend/internal/api/handlers"
	"github.com/chspring1/mya-platform/backend/internal/api/middleware"
	"github.com/gin-gonic/gin"
)

func SetupRouter() *gin.Engine {
	gin.SetMode(gin.ReleaseMode)

	router := gin.New()

	// 使用中间件
	router.Use(gin.Recovery())
	router.Use(middleware.Logger())
	router.Use(middleware.CORS())
	router.Use(middleware.Security())
	router.Use(middleware.RateLimit(60))

	// 创建 handlers
	handlers := handlers.NewHandlers()

	// 健康检查
	router.GET("/health", handlers.HealthCheck)

	// API v1 路由组
	v1 := router.Group("/api/v1")
	{
		// 公开路由
		v1.GET("/vaults", handlers.GetVaults)
		v1.GET("/vaults/:address", handlers.GetVaultDetail)
		v1.GET("/strategies", handlers.GetStrategies)
		v1.GET("/apy", handlers.GetAPYData)

		// 需要认证的路由组
		auth := v1.Group("/")
		auth.Use(middleware.AuthRequired())
		{
			auth.GET("/users/:address", handlers.GetUserInfo)
			auth.GET("/users/:address/positions", handlers.GetUserPositions)
			auth.POST("/vaults/:address/deposit", handlers.DepositToVault)
			auth.POST("/vaults/:address/withdraw", handlers.WithdrawFromVault)
		}

		// 管理员路由组
		admin := v1.Group("/admin")
		admin.Use(middleware.AdminRequired())
		{
			admin.GET("/stats", handlers.GetSystemStats)
			admin.POST("/vaults/:address/emergency-stop", handlers.EmergencyStopVault)
			admin.GET("/monitoring", handlers.GetMonitoringData)
		}

		// 风控路由
		risk := v1.Group("/risk")
		risk.Use(middleware.AuthRequired())
		{
			risk.GET("/alerts", handlers.GetRiskAlerts)
			risk.POST("/strategies/:address/check", handlers.CheckStrategyRisk)
		}
	}

	return router
}
