package middleware

import (
	"fmt"
	"time"

	"github.com/chspring1/mya-platform/backend/pkg/logger"
	"github.com/gin-gonic/gin"
)

func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		method := c.Request.Method

		c.Next()

		end := time.Now()
		latency := end.Sub(start)
		status := c.Writer.Status()

		logger.Info(fmt.Sprintf("%s %s %d %v",
			method,
			path,
			status,
			latency,
		))
	}
}
