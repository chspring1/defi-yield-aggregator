package config

import (
	"sync"

	"github.com/spf13/viper"
)

type Config struct {
	Server   ServerConfig   `mapstructure:"server"`
	Database DatabaseConfig `mapstructure:"database"`
	Redis    RedisConfig    `mapstructure:"redis"`
}

type ServerConfig struct {
	Port string `mapstructure:"port"`
	Mode string `mapstructure:"mode"`
}

type DatabaseConfig struct {
	Host     string `mapstructure:"host"`
	Port     string `mapstructure:"port"`
	User     string `mapstructure:"user"`
	Password string `mapstructure:"password"`
	DBName   string `mapstructure:"dbname"`
	SSLMode  string `mapstructure:"sslmode"`
}

type RedisConfig struct {
	Host string `mapstructure:"host"`
	Port string `mapstructure:"port"`
	DB   int    `mapstructure:"db"`
}

var (
	config *Config
	once   sync.Once
)

func Load() *Config {
	once.Do(func() {
		// 设置配置文件路径和名称
		viper.SetConfigName("config")
		viper.SetConfigType("yaml")
		viper.AddConfigPath("./configs")
		viper.AddConfigPath("../configs")
		viper.AddConfigPath("../../configs")

		// 读取配置文件
		if err := viper.ReadInConfig(); err != nil {
			// 如果读取失败，使用默认值
			viper.SetDefault("server.port", "8080")
			viper.SetDefault("server.mode", "debug")
			viper.SetDefault("database.host", "localhost")
			viper.SetDefault("database.port", "5432")
			viper.SetDefault("database.user", "mya_user")
			viper.SetDefault("database.password", "mya_password")
			viper.SetDefault("database.dbname", "mya_platform")
			viper.SetDefault("database.sslmode", "disable")
			viper.SetDefault("redis.host", "localhost")
			viper.SetDefault("redis.port", "6379")
			viper.SetDefault("redis.db", 0)
		}

		// 从环境变量读取（会覆盖配置文件中的值）
		viper.AutomaticEnv()

		config = &Config{
			Server: ServerConfig{
				Port: viper.GetString("server.port"),
				Mode: viper.GetString("server.mode"),
			},
			Database: DatabaseConfig{
				Host:     viper.GetString("database.host"),
				Port:     viper.GetString("database.port"),
				User:     viper.GetString("database.user"),
				Password: viper.GetString("database.password"),
				DBName:   viper.GetString("database.dbname"),
				SSLMode:  viper.GetString("database.sslmode"),
			},
			Redis: RedisConfig{
				Host: viper.GetString("redis.host"),
				Port: viper.GetString("redis.port"),
				DB:   viper.GetInt("redis.db"),
			},
		}
	})

	return config
}
