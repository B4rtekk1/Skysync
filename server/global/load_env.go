package global

import (
	"log"
	"os"
	"skysync/utils"

	"github.com/joho/godotenv"
)

var ENCRYPTION_KEY string
var SECRET_KEY string
var API_KEY string
var BASE_URL string
var AppConfig *utils.Config

func SetConfig(config *utils.Config) {
	AppConfig = config
}

func GetConfig() *utils.Config {
	return AppConfig
}

func LoadEnv() {
	cwd, _ := os.Getwd()
	log.Printf("Current working directory: %s", cwd)

	err := godotenv.Load(".env")
	if err != nil {
		log.Printf("Error loading .env file: %v", err)
		log.Println("No .env file found in current directory, relying on environment variables")
		return
	}
	log.Println(".env file loaded successfully")
	ENCRYPTION_KEY = os.Getenv("ENCRYPTION_KEY")
	SECRET_KEY = os.Getenv("SECRET_KEY")
	API_KEY = os.Getenv("API_KEY")
	BASE_URL = os.Getenv("BASE_URL")
}
