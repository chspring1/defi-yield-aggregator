package middleware

import (
	"fmt"
	"net/http"
	"github.com/chspring1/mya-platform/backend/pkg/logger"
	"github.com/gin-gonic/gin"
)

// AuthRequired 需要认证的中间件
func AuthRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		userAddress := c.GetHeader("X-User-Address")
		if userAddress == "" {
			logger.Info("Authentication failed: missing X-User-Address header")
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "Authentication required. Please provide X-User-Address header",
			})
			c.Abort()
			return
		}

		// 简单的地址格式验证
		if len(userAddress) != 42 || userAddress[:2] != "0x" {
			logger.Info(fmt.Sprintf("Authentication failed: invalid address format %s", userAddress))
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid Ethereum address format",
			})
			c.Abort()
			return
		}

		// 设置用户地址到上下文
		c.Set("user_address", userAddress)
		logger.Info(fmt.Sprintf("User authenticated: %s", userAddress))
		c.Next()
	}
}

// AdminRequired 需要管理员权限的中间件
func AdminRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		userAddress := c.GetHeader("X-User-Address")
		
		// 临时实现：检查特定管理员地址
		adminAddresses := map[string]bool{
			"0xAdminAddress": true,
			"0x742d35Cc6634C0532925a3b8Dc9F1a37cD7e8b5d": true, // 示例地址
		}
		
		if !adminAddresses[userAddress] {
			logger.Info(fmt.Sprintf("Admin access denied for: %s", userAddress))
			c.JSON(http.StatusForbidden, gin.H{
				"error": "Admin access required",
			})
			c.Abort()
			return
		}

		logger.Info(fmt.Sprintf("Admin access granted: %s", userAddress))
		c.Next()
	}
}

// Security 安全头中间件
func Security() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Frame-Options", "DENY")
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-XSS-Protection", "1; mode=block")
		c.Header("Strict-Transport-Security", "max-age=31536000")
		c.Next()
	}
}