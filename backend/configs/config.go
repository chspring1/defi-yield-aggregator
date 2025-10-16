package config

import (
	"log"
	"sync"

	"github.com/spf13/viper"
)

type Config struct {
	Server     ServerConfig     `mapstructure:"server"`
	Database   DatabaseConfig   `mapstructure:"database"`
	Redis      RedisConfig      `mapstructure:"redis"`
	Kafka      KafkaConfig      `mapstructure:"kafka"`
	Blockchain BlockchainConfig `mapstructure:"blockchain"`
	Auth       AuthConfig       `mapstructure:"auth"`
}

type ServerConfig struct {
	Port         string `mapstructure:"port"`
	Mode         string `mapstructure:"mode"` // debug, release, test
	ReadTimeout  int    `mapstructure:"read_timeout"`
	WriteTimeout int    `mapstructure:"write_timeout"`
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
	Host     string `mapstructure:"host"`
	Port     string `mapstructure:"port"`
	Password string `mapstructure:"password"`
	DB       int    `mapstructure:"db"`
}

type KafkaConfig struct {
	Brokers  []string `mapstructure:"brokers"`
	GroupID  string   `mapstructure:"group_id"`
	ClientID string   `mapstructure:"client_id"`
}

type BlockchainConfig struct {
	EthereumRPC string `mapstructure:"ethereum_rpc"`
	PolygonRPC  string `mapstructure:"polygon_rpc"`
	ArbitrumRPC string `mapstructure:"arbitrum_rpc"`
	ChainID     int64  `mapstructure:"chain_id"`
}

type AuthConfig struct {
	JWTSecret   string `mapstructure:"jwt_secret"`
	JWTDuration int    `mapstructure:"jwt_duration"` // in hours
}

var (
	config *Config
	once   sync.Once
)

// Load 加载配置
func Load() *Config {
	once.Do(func() {
		viper.SetConfigName("config")
		viper.SetConfigType("yaml")
		viper.AddConfigPath("./configs")
		viper.AddConfigPath(".")

		// 设置默认值
		setDefaults()

		// 读取环境变量
		bindEnvVars()

		// 读取配置文件
		if err := viper.ReadInConfig(); err != nil {
			log.Printf("Warning: Could not read config file: %v", err)
		}

		// 反序列化配置到结构体
		if err := viper.Unmarshal(&config); err != nil {
			log.Fatalf("Unable to decode config into struct: %v", err)
		}
	})

	return config
}

func setDefaults() {
	viper.SetDefault("server.port", "8080")
	viper.SetDefault("server.mode", "debug")
	viper.SetDefault("server.read_timeout", 30)
	viper.SetDefault("server.write_timeout", 30)

	viper.SetDefault("database.host", "localhost")
	viper.SetDefault("database.port", "5432")
	viper.SetDefault("database.user", "mya_user")
	viper.SetDefault("database.dbname", "mya_platform")
	viper.SetDefault("database.sslmode", "disable")

	viper.SetDefault("redis.host", "localhost")
	viper.SetDefault("redis.port", "6379")
	viper.SetDefault("redis.db", 0)

	viper.SetDefault("kafka.brokers", []string{"localhost:9092"})
	viper.SetDefault("kafka.group_id", "mya-api-group")
	viper.SetDefault("kafka.client_id", "mya-api-server")

	viper.SetDefault("blockchain.ethereum_rpc", "https://eth.llamarpc.com")
	viper.SetDefault("blockchain.polygon_rpc", "https://polygon-rpc.com")
	viper.SetDefault("blockchain.arbitrum_rpc", "https://arb1.arbitrum.io/rpc")
	viper.SetDefault("blockchain.chain_id", 1)

	viper.SetDefault("auth.jwt_duration", 24)
}

func bindEnvVars() {
	viper.BindEnv("server.port", "API_PORT")
	viper.BindEnv("database.host", "DB_HOST")
	viper.BindEnv("database.port", "DB_PORT")
	viper.BindEnv("database.user", "DB_USER")
	viper.BindEnv("database.password", "DB_PASSWORD")
	viper.BindEnv("database.dbname", "DB_NAME")
	viper.BindEnv("redis.host", "REDIS_HOST")
	viper.BindEnv("redis.port", "REDIS_PORT")
	viper.BindEnv("redis.password", "REDIS_PASSWORD")
	viper.BindEnv("redis.db", "REDIS_DB")
	viper.BindEnv("auth.jwt_secret", "JWT_SECRET")
}
