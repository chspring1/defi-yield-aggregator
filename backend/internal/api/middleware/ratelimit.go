package middleware

import (
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/chspring1/mya-platform/backend/pkg/logger"
	"github.com/gin-gonic/gin"
)

// Client 表示一个客户端的速率限制信息
type Client struct {
	requests  int
	lastReset time.Time
	mutex     sync.Mutex
}

// RateLimiter 速率限制器
type RateLimiter struct {
	clients map[string]*Client
	mutex   sync.RWMutex
	limit   int           // 每分钟允许的请求数
	window  time.Duration // 时间窗口
}

// NewRateLimiter 创建新的速率限制器
func NewRateLimiter(requestsPerMinute int) *RateLimiter {
	rl := &RateLimiter{
		clients: make(map[string]*Client),
		limit:   requestsPerMinute,
		window:  time.Minute,
	}

	// 启动清理goroutine
	go rl.cleanup()

	return rl
}

// Allow 检查是否允许请求
func (rl *RateLimiter) Allow(clientIP string) bool {
	rl.mutex.Lock()
	defer rl.mutex.Unlock()

	client, exists := rl.clients[clientIP]
	if !exists {
		client = &Client{
			requests:  1,
			lastReset: time.Now(),
		}
		rl.clients[clientIP] = client
		return true
	}

	client.mutex.Lock()
	defer client.mutex.Unlock()

	now := time.Now()

	// 检查是否需要重置计数器
	if now.Sub(client.lastReset) >= rl.window {
		client.requests = 1
		client.lastReset = now
		return true
	}

	// 检查是否超过限制
	if client.requests >= rl.limit {
		return false
	}

	client.requests++
	return true
}

// GetRemainingRequests 获取剩余请求次数
func (rl *RateLimiter) GetRemainingRequests(clientIP string) int {
	rl.mutex.RLock()
	defer rl.mutex.RUnlock()

	client, exists := rl.clients[clientIP]
	if !exists {
		return rl.limit
	}

	client.mutex.Lock()
	defer client.mutex.Unlock()

	now := time.Now()
	if now.Sub(client.lastReset) >= rl.window {
		return rl.limit
	}

	remaining := rl.limit - client.requests
	if remaining < 0 {
		return 0
	}
	return remaining
}

// cleanup 定期清理过期的客户端记录
func (rl *RateLimiter) cleanup() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		rl.mutex.Lock()
		now := time.Now()
		for ip, client := range rl.clients {
			client.mutex.Lock()
			if now.Sub(client.lastReset) > 2*rl.window {
				delete(rl.clients, ip)
			}
			client.mutex.Unlock()
		}
		rl.mutex.Unlock()
	}
}

var globalRateLimiter *RateLimiter

// RateLimit 速率限制中间件
func RateLimit(requestsPerMinute int) gin.HandlerFunc {
	if globalRateLimiter == nil {
		globalRateLimiter = NewRateLimiter(requestsPerMinute)
	}

	return func(c *gin.Context) {
		clientIP := c.ClientIP()

		if !globalRateLimiter.Allow(clientIP) {
			remaining := globalRateLimiter.GetRemainingRequests(clientIP)

			// 记录速率限制日志
			logger.Info(fmt.Sprintf("Rate limit exceeded for IP: %s", clientIP))

			c.Header("X-RateLimit-Limit", fmt.Sprintf("%d", requestsPerMinute))
			c.Header("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
			c.Header("X-RateLimit-Reset", fmt.Sprintf("%d", time.Now().Add(time.Minute).Unix()))

			c.JSON(http.StatusTooManyRequests, gin.H{
				"error":       "Rate limit exceeded",
				"message":     fmt.Sprintf("Too many requests. Limit: %d requests per minute", requestsPerMinute),
				"retry_after": 60,
			})
			c.Abort()
			return
		}

		// 添加速率限制头信息
		remaining := globalRateLimiter.GetRemainingRequests(clientIP)
		c.Header("X-RateLimit-Limit", fmt.Sprintf("%d", requestsPerMinute))
		c.Header("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
		c.Header("X-RateLimit-Reset", fmt.Sprintf("%d", time.Now().Add(time.Minute).Unix()))

		c.Next()
	}
}
