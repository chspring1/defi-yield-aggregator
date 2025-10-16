package routes

import (
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
	router.Use(middleware.RateLimit(60)) // 每分钟60次请求

	// 健康检查
	router.GET("/health", healthCheck)

	// API v1 路由组
	v1 := router.Group("/api/v1")
	{
		// 公开路由
		v1.GET("/vaults", getVaults)
		v1.GET("/vaults/:address", getVaultDetail)
		v1.GET("/strategies", getStrategies)
		v1.GET("/apy", getAPYData)
		
		// 需要认证的路由组
		auth := v1.Group("/")
		auth.Use(middleware.AuthRequired())
		{
			auth.GET("/users/:address", getUserInfo)
			auth.GET("/users/:address/positions", getUserPositions)
			auth.POST("/vaults/:address/deposit", depositToVault)
			auth.POST("/vaults/:address/withdraw", withdrawFromVault)
		}

		// 管理员路由组
		admin := v1.Group("/admin")
		admin.Use(middleware.AdminRequired())
		{
			admin.GET("/stats", getSystemStats)
			admin.POST("/vaults/:address/emergency-stop", emergencyStopVault)
			admin.GET("/monitoring", getMonitoringData)
		}
	}

	return router
}

func healthCheck(c *gin.Context) {
	c.JSON(200, gin.H{
		"status":    "healthy", 
		"service":   "mya-platform-api",
		"framework": "gin",
		"version":   "1.0.0",
	})
}

func getVaults(c *gin.Context) {
	c.JSON(200, gin.H{
		"vaults": []gin.H{
			{
				"address": "0xVault1",
				"name":    "USDC Yield Vault", 
				"tvl":     "1000000.00",
				"apy":     "0.0525",
				"chain":   "Ethereum",
				"asset":   "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC
			},
			{
				"address": "0xVault2", 
				"name":    "ETH Staking Vault",
				"tvl":     "500000.00",
				"apy":     "0.0420",
				"chain":   "Ethereum",
				"asset":   "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", // WETH
			},
		},
	})
}

func getVaultDetail(c *gin.Context) {
	address := c.Param("address") // 从url获取地址参数
	c.JSON(200, gin.H{
		"vault": gin.H{
			"address":          address, // 使用获取到的地址
			"name":             "USDC Yield Vault",
			"tvl":              "1000000.00", 
			"apy":              "0.0525",
			"strategy":         "0xStrategy1",
			"asset":            "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
			"total_deposits":   "1500000.00",
			"total_withdrawals": "500000.00",
			"created":          "2024-01-01T00:00:00Z",
			"is_active":        true, // 是否活跃
		},
	})
}

func getStrategies(c *gin.Context) {
	c.JSON(200, gin.H{
		"strategies": []gin.H{
			{
				"address":      "0xStrategy1",
				"name":         "AAVE Lending Strategy",
				"vault":        "0xVault1",
				"apy":          "0.0480",
				"risk_score":   2,
				"total_assets": "950000.00",
				"is_active":    true,
			},
			{
				"address":      "0xStrategy2", 
				"name":         "Compound Supply Strategy",
				"vault":        "0xVault1",
				"apy":          "0.0450",
				"risk_score":   2,
				"total_assets": "50000.00",
				"is_active":    true,
			},
		},
	})
}

func getAPYData(c *gin.Context) {
	c.JSON(200, gin.H{
		"apy_data": []gin.H{
			{
				"vault": "0xVault1",
				"apy_7d":  "0.0521",
				"apy_30d": "0.0518", 
				"apy_90d": "0.0505",
			},
			{
				"vault": "0xVault2",
				"apy_7d":  "0.0415",
				"apy_30d": "0.0422",
				"apy_90d": "0.0410",
			},
		},
	})
}

func getUserInfo(c *gin.Context) {
	userAddress := c.Param("address")
	c.JSON(200, gin.H{
		"user": gin.H{
			"address":    userAddress,
			"total_tvl":  "25000.00",
			"total_apy":  "0.0495",
			"joined_at":  "2024-01-15T00:00:00Z",
			"vault_count": 2,
		},
	})
}

func depositToVault(c *gin.Context) {
	vaultAddress := c.Param("address")
	userAddress, _ := c.Get("user_address")
	
	c.JSON(200, gin.H{
		"transaction": gin.H{
			"hash":    "0xTxHash123",
			"status":  "pending",
			"vault":   vaultAddress,
			"user":    userAddress,
			"amount":  "1000.00",
			"type":    "deposit",
		},
	})
}

func withdrawFromVault(c *gin.Context) {
	vaultAddress := c.Param("address")
	userAddress, _ := c.Get("user_address")
	
	c.JSON(200, gin.H{
		"transaction": gin.H{
			"hash":    "0xTxHash456",
			"status":  "pending", 
			"vault":   vaultAddress,
			"user":    userAddress,
			"amount":  "500.00",
			"type":    "withdraw",
		},
	})
}

func getUserPositions(c *gin.Context) {
	userAddress := c.Param("address")
	
	c.JSON(200, gin.H{
		"positions": []gin.H{
			{   "userAddress": userAddress,
				"vault_address": "0xVault1",
				"vault_name":    "USDC Yield Vault",
				"shares":        "25000.000000",
				"assets":        "25625.000000",
				"apy":           "0.0525",
				"value_usd":     "25625.00",
			},
			{
				"vault_address": "0xVault2",
				"vault_name":    "ETH Staking Vault", 
				"shares":        "1.500000",
				"assets":        "1.530000",
				"apy":           "0.0420",
				"value_usd":     "2800.00",
			},
		},
	})
}

func getSystemStats(c *gin.Context) {
	c.JSON(200, gin.H{
		"stats": gin.H{
			"total_tvl":          "1500000.00",
			"total_users":        125,
			"total_vaults":       3,
			"total_strategies":   5,
			"total_deposits":     "2500000.00",
			"total_withdrawals":  "1000000.00",
			"total_yield":        "75000.00",
			"avg_apy":            "0.0485",
			"updated_at":         "2024-01-20T12:00:00Z",
		},
	})
}

func emergencyStopVault(c *gin.Context) {
	vaultAddress := c.Param("address")
	
	c.JSON(200, gin.H{
		"action": "emergency_stop",
		"vault":  vaultAddress,
		"status": "stopped",
		"message": "Vault has been emergency stopped",
	})
}

func getMonitoringData(c *gin.Context) {
	c.JSON(200, gin.H{
		"monitoring": gin.H{
			"active_connections": 45,
			"request_per_minute": 120,
			"error_rate": "0.02",
			"response_time_avg": "45ms",
			"database_connections": 12,
			"last_updated": "2024-01-20T12:00:00Z",
		},
	})
}