package server

import (
	"fmt"
	"net/http"

	"github.com/chspring1/mya-platform/backend/pkg/logger"

	"github.com/gin-gonic/gin"
)

type Server struct {
	router *gin.Engine
	port   string
}

func New(port string) *Server {
	// 设置Gin模式
	gin.SetMode(gin.ReleaseMode)

	router := gin.New()

	// 全局中间件
	router.Use(gin.Recovery())
	router.Use(loggerMiddleware())

	server := &Server{
		router: router,
		port:   port,
	}

	server.setupRoutes()

	return server
}

func (s *Server) setupRoutes() {
	// 健康检查
	s.router.GET("/health", s.healthCheck)

	// API v1 路由组
	v1 := s.router.Group("/api/v1")
	{
		v1.GET("/vaults", s.getVaults)
		v1.GET("/vaults/:address", s.getVaultDetail)
		v1.GET("/strategies", s.getStrategies)
	}
}

func (s *Server) healthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"service":   "mya-platform-api",
		"timestamp": "2024-01-01T00:00:00Z",
	})
}

func (s *Server) getVaults(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"vaults": []gin.H{
			{
				"address": "0xVault1",
				"name":    "USDC Yield Vault",
				"tvl":     "1000000.00",
				"apy":     "0.0525",
			},
		},
	})
}

func (s *Server) getVaultDetail(c *gin.Context) {
	vaultAddress := c.Param("address")

	c.JSON(http.StatusOK, gin.H{
		"vault": gin.H{
			"address": vaultAddress,
			"name":    "USDC Yield Vault",
			"tvl":     "1000000.00",
			"apy":     "0.0525",
		},
	})
}

func (s *Server) getStrategies(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"strategies": []gin.H{
			{
				"address":    "0xStrategy1",
				"name":       "AAVE Lending Strategy",
				"vault":      "0xVault1",
				"apy":        "0.0480",
				"risk_score": 2,
			},
		},
	})
}

func (s *Server) Start() error {
	addr := ":" + s.port
	logger.Info(fmt.Sprintf("Starting Gin server on %s", addr))
	return s.router.Run(addr)
}

func loggerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		logger.Info(fmt.Sprintf("HTTP %s %s", c.Request.Method, c.Request.URL.Path))
		c.Next()
	}
}
