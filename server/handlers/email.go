package handlers

import (
	"fmt"
	"log"
	"net/mail"
	"net/smtp"
	"os"
	"regexp"
	"strings"
)

type EmailConfig struct {
	SMTPServer  string
	SMTPPort    string
	SenderEmail string
	SenderPass  string
}

var emailConfig EmailConfig

func getEmailConfig() EmailConfig {
	return EmailConfig{
		SMTPServer:  os.Getenv("SMTP_SERVER"),
		SMTPPort:    os.Getenv("SMTP_PORT"),
		SenderEmail: os.Getenv("EMAIL"),
		SenderPass:  os.Getenv("PASSWORD"),
	}
}

func validateEmail(email string) error {
	_, err := mail.ParseAddress(email)
	if err != nil {
		return fmt.Errorf("invalid email address: %v", err)
	}

	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9.!#$%&'*+/=?^_` + "`" + `{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$`)
	if !emailRegex.MatchString(email) {
		return fmt.Errorf("email format does not match security requirements")
	}

	return nil
}

func sanitizeHeaderValue(value string) string {
	value = strings.ReplaceAll(value, "\r", "")
	value = strings.ReplaceAll(value, "\n", "")
	value = strings.Map(func(r rune) rune {
		if r < 32 && r != 9 {
			return -1
		}
		return r
	}, value)
	return value
}

func validateToken(token string) error {
	const maxTokenLength = 200
	if len(token) == 0 {
		return fmt.Errorf("token cannot be empty")
	}
	if len(token) > maxTokenLength {
		return fmt.Errorf("token exceeds maximum length of %d characters", maxTokenLength)
	}
	for _, r := range token {
		if r < 32 && r != 9 {
			return fmt.Errorf("token contains invalid control characters")
		}
	}
	return nil
}

func SendVerificationEmail(toEmail, verificationCode string) error {
	emailConfig = getEmailConfig()
	if emailConfig.SenderEmail == "" || emailConfig.SenderPass == "" {
		log.Println("Email config not set, skipping email sending")
		return nil
	}

	if err := validateEmail(toEmail); err != nil {
		return fmt.Errorf("invalid email address: %v", err)
	}

	if err := validateToken(verificationCode); err != nil {
		return fmt.Errorf("invalid verification code: %v", err)
	}

	safeToEmail := sanitizeHeaderValue(toEmail)
	safeFromEmail := sanitizeHeaderValue(emailConfig.SenderEmail)

	subject := sanitizeHeaderValue("Email Verification - Skysync")
	body := fmt.Sprintf(`Hello,

Your verification code is: %s

This code will expire in 15 minutes.

If you did not request this verification, please ignore this email.

Best regards,
Skysync Team`, sanitizeHeaderValue(verificationCode))

	msg := fmt.Appendf(nil, "From: %s\r\n"+
		"To: %s\r\n"+
		"Subject: %s\r\n"+
		"MIME-Version: 1.0\r\n"+
		"Content-Type: text/plain; charset=UTF-8\r\n"+
		"\r\n"+
		"%s\r\n", safeFromEmail, safeToEmail, subject, body)

	auth := smtp.PlainAuth("", emailConfig.SenderEmail, emailConfig.SenderPass, emailConfig.SMTPServer)

	smtpAddr := fmt.Sprintf("%s:%s", emailConfig.SMTPServer, emailConfig.SMTPPort)

	err := smtp.SendMail(smtpAddr, auth, emailConfig.SenderEmail, []string{safeToEmail}, msg)
	if err != nil {
		return fmt.Errorf("failed to send verification email: %v", err)
	}

	log.Printf("Verification email sent to %s", toEmail)
	return nil
}

func SendPasswordResetEmail(toEmail, resetToken string) error {
	emailConfig = getEmailConfig()
	if emailConfig.SenderEmail == "" || emailConfig.SenderPass == "" {
		log.Println("Email config not set, skipping email sending")
		return nil
	}

	if err := validateEmail(toEmail); err != nil {
		return fmt.Errorf("invalid email address: %v", err)
	}

	if err := validateToken(resetToken); err != nil {
		return fmt.Errorf("invalid reset token: %v", err)
	}

	safeToEmail := sanitizeHeaderValue(toEmail)
	safeFromEmail := sanitizeHeaderValue(emailConfig.SenderEmail)

	subject := sanitizeHeaderValue("Password Reset - Skysync")
	body := fmt.Sprintf(`Hello,

You requested a password reset for your Skysync account.

Your reset token is: %s

This token expires in 1 hour.

If you did not request this, please ignore this email.

Best regards,
Skysync Team`, sanitizeHeaderValue(resetToken))

	msg := fmt.Appendf(nil, "From: %s\r\n"+
		"To: %s\r\n"+
		"Subject: %s\r\n"+
		"MIME-Version: 1.0\r\n"+
		"Content-Type: text/plain; charset=UTF-8\r\n"+
		"\r\n"+
		"%s\r\n", safeFromEmail, safeToEmail, subject, body)

	auth := smtp.PlainAuth("", emailConfig.SenderEmail, emailConfig.SenderPass, emailConfig.SMTPServer)
	smtpAddr := fmt.Sprintf("%s:%s", emailConfig.SMTPServer, emailConfig.SMTPPort)

	err := smtp.SendMail(smtpAddr, auth, emailConfig.SenderEmail, []string{safeToEmail}, msg)
	if err != nil {
		return fmt.Errorf("failed to send password reset email: %v", err)
	}

	return nil
}

func SendAccountDeletionEmail(toEmail, deletionToken string) error {
	emailConfig = getEmailConfig()
	if emailConfig.SenderEmail == "" || emailConfig.SenderPass == "" {
		log.Println("Email config not set, skipping email sending")
		return nil
	}

	if err := validateEmail(toEmail); err != nil {
		return fmt.Errorf("invalid email address: %v", err)
	}

	if err := validateToken(deletionToken); err != nil {
		return fmt.Errorf("invalid deletion token: %v", err)
	}

	safeToEmail := sanitizeHeaderValue(toEmail)
	safeFromEmail := sanitizeHeaderValue(emailConfig.SenderEmail)

	subject := sanitizeHeaderValue("Account Deletion Confirmation - Skysync")
	body := fmt.Sprintf(`⚠️ ACCOUNT DELETION REQUEST

Hello,

You requested to delete your Skysync account.

Deletion token: %s

⚠️ This action is IRREVERSIBLE!
- All files will be permanently deleted
- All data will be permanently removed

Token expires in 1 hour.

If you did not request this, ignore this email.

Best regards,
Skysync Team`, sanitizeHeaderValue(deletionToken))

	msg := fmt.Appendf(nil, "From: %s\r\n"+
		"To: %s\r\n"+
		"Subject: %s\r\n"+
		"MIME-Version: 1.0\r\n"+
		"Content-Type: text/plain; charset=UTF-8\r\n"+
		"\r\n"+
		"%s\r\n", safeFromEmail, safeToEmail, subject, body)

	auth := smtp.PlainAuth("", emailConfig.SenderEmail, emailConfig.SenderPass, emailConfig.SMTPServer)
	smtpAddr := fmt.Sprintf("%s:%s", emailConfig.SMTPServer, emailConfig.SMTPPort)

	err := smtp.SendMail(smtpAddr, auth, emailConfig.SenderEmail, []string{safeToEmail}, msg)
	if err != nil {
		return fmt.Errorf("failed to send deletion email: %v", err)
	}

	log.Printf("Account deletion email sent to %s", toEmail)
	return nil
}
