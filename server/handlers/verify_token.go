package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func VerifyTokenEndpoint() gin.HandlerFunc {
	return func(c *gin.Context) {
		// If the request reaches here, it has passed the JWTMiddleware,
		// so the token is valid.
		c.JSON(http.StatusOK, gin.H{"message": "Token is valid"})
	}
}
