package handlers

import (
	"fmt"
	"log"
	"net/smtp"
	"os"
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

func SendVerificationEmail(toEmail, verificationCode string) error {
	emailConfig = getEmailConfig()
	if emailConfig.SenderEmail == "" || emailConfig.SenderPass == "" {
		log.Println("Email config not set, skipping email sending")
		return nil
	}

	subject := "Email Verification - Skysync"
	body := fmt.Sprintf(`Hello,

Your verification code is: %s

This code will expire in 15 minutes.

If you did not request this verification, please ignore this email.

Best regards,
Skysync Team`, verificationCode)

	msg := fmt.Appendf(nil, "To: %s\r\n"+
		"Subject: %s\r\n"+
		"\r\n"+
		"%s\r\n", toEmail, subject, body)

	auth := smtp.PlainAuth("", emailConfig.SenderEmail, emailConfig.SenderPass, emailConfig.SMTPServer)

	smtpAddr := fmt.Sprintf("%s:%s", emailConfig.SMTPServer, emailConfig.SMTPPort)

	err := smtp.SendMail(smtpAddr, auth, emailConfig.SenderEmail, []string{toEmail}, msg)
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

	subject := "Password Reset - Skysync"
	body := fmt.Sprintf(`Hello,

You requested a password reset for your Skysync account.

Your reset token is: %s

This token expires in 1 hour.

If you did not request this, please ignore this email.

Best regards,
Skysync Team`, resetToken)

	msg := fmt.Appendf(nil, "To: %s\r\n"+
		"Subject: %s\r\n"+
		"\r\n"+
		"%s\r\n", toEmail, subject, body)

	auth := smtp.PlainAuth("", emailConfig.SenderEmail, emailConfig.SenderPass, emailConfig.SMTPServer)
	smtpAddr := fmt.Sprintf("%s:%s", emailConfig.SMTPServer, emailConfig.SMTPPort)

	err := smtp.SendMail(smtpAddr, auth, emailConfig.SenderEmail, []string{toEmail}, msg)
	if err != nil {
		return fmt.Errorf("failed to send password reset email: %v", err)
	}

	return nil
}

func SendAccountDeletionEmail(toEmail, deletionToken string) error {
	if emailConfig.SenderEmail == "" || emailConfig.SenderPass == "" {
		return nil
	}

	subject := "Account Deletion Confirmation - Skysync"
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
Skysync Team`, deletionToken)

	msg := []byte(fmt.Sprintf("To: %s\r\n"+
		"Subject: %s\r\n"+
		"\r\n"+
		"%s\r\n", toEmail, subject, body))

	auth := smtp.PlainAuth("", emailConfig.SenderEmail, emailConfig.SenderPass, emailConfig.SMTPServer)
	smtpAddr := fmt.Sprintf("%s:%s", emailConfig.SMTPServer, emailConfig.SMTPPort)

	err := smtp.SendMail(smtpAddr, auth, emailConfig.SenderEmail, []string{toEmail}, msg)
	if err != nil {
		return fmt.Errorf("failed to send deletion email: %v", err)
	}

	return nil
}
