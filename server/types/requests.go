package types

type EncryptFileRequest struct {
	Filename   string `json:"filename" binding:"required,min=1,max=255"`
	FolderName string `json:"folder_name" binding:"required,min=1,max=255"`
	Password   string `json:"password" binding:"required,min=8,max=128"`
}

type DecryptFileRequest struct {
	Filename   string `json:"filename" binding:"required,min=1,max=255"`
	FolderName string `json:"folder_name" binding:"required,min=1,max=255"`
	Password   string `json:"password" binding:"required,min=8,max=128"`
}

// RegisterRequest defines the request structure for user registration
type RegisterRequest struct {
	Username string `json:"username" binding:"required,min=3,max=50"`
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8,max=128"`
}

// LoginRequest defines the request structure for user login
type LoginRequest struct {
	Username string `json:"username" binding:"required,min=3,max=50"`
	Password string `json:"password" binding:"required,min=8,max=128"`
}

// UpdatePasswordRequest defines the request structure for updating user password
type UpdatePasswordRequest struct {
	CurrentPassword string `json:"current_password" binding:"required,min=8,max=128"`
	NewPassword     string `json:"new_password" binding:"required,min=8,max=128"`
}

// VerifyEmailRequest defines the request structure for email verification
type VerifyEmailRequest struct {
	VerificationCode string `json:"code" binding:"required,min=6,max=6"`
	Email            string `json:"email" binding:"required,email"`
}

type ResendVerificationRequest struct {
	Email string `json:"email" binding:"required,email"`
}

// ResetPasswordRequest defines the request structure for initiating password reset
type ResetPasswordRequest struct {
	Email string `json:"email" binding:"required,email"`
}

type ValidateResetTokenEndpoint struct {
	ResetToken string `json:"reset_token" binding:"required,min=1,max=255"`
}

// ConfirmResetPasswordRequest defines the request structure for confirming password reset
type ConfirmResetPasswordRequest struct {
	Code        string `json:"code" binding:"required,min=6,max=6"`
	NewPassword string `json:"new_password" binding:"required,min=8,max=128"`
	Email       string `json:"email" binding:"required,email"`
}

// DeleteAccountRequest defines the request structure for initiating account deletion
type DeleteAccountRequest struct {
	Password string `json:"password" binding:"required,min=8,max=128"`
}

// ConfirmDeleteAccountRequest defines the request structure for confirming account deletion
type ConfirmDeleteAccountRequest struct {
	DeletionToken string `json:"deletion_token" binding:"required,min=1,max=255"`
}

type ListFilesRequest struct {
	FolderName string `json:"folder_name" binding:"max=255"`
}

// UploadFileRequest defines the request structure for file upload
type UploadFileRequest struct {
	Filename   string `json:"filename" binding:"required,min=1,max=255"`
	FolderName string `json:"folder_name" binding:"required,min=1,max=255"`
	MimeType   string `json:"mime_type" binding:"required,min=1,max=255"`
	// File content is typically handled via multipart form data, not JSON
}

// DeleteFileRequest defines the request structure for file deletion
type DeleteFileRequest struct {
	FilePath string `json:"file_path" binding:"required,min=1,max=255"`
}

// RenameFileRequest defines the request structure for renaming a file
type RenameFileRequest struct {
	Filename    string `json:"filename" binding:"required,min=1,max=255"`
	FolderName  string `json:"folder_name" binding:"required,min=1,max=255"`
	NewFilename string `json:"new_filename" binding:"required,min=1,max=255"`
}

// AddFavoriteRequest defines the request structure for adding a file to favorites
type AddFavoriteRequest struct {
	Filename   string `json:"filename" binding:"required,min=1,max=255"`
	FolderName string `json:"folder_name" binding:"required,min=1,max=255"`
}

// QuickShareRequest defines the request structure for creating a quick share link
type QuickShareRequest struct {
	FilePath      string `json:"file_path" binding:"required,min=1"`
	DownloadLimit int    `json:"download_limit" binding:"min=1"`
	ExpiresIn     int    `json:"expires_in" binding:"min=1"`
}
type RemoveFavoriteRequest struct {
	Filename   string `json:"filename" binding:"required,min=1,max=255"`
	FolderName string `json:"folder_name" binding:"required,min=1,max=255"`
}

// CreateFolderRequest defines the request structure for creating a folder
type CreateFolderRequest struct {
	FolderName string `json:"folder_name" binding:"required,min=1,max=255"`
}

// DeleteFolderRequest defines the request structure for deleting a folder
type DeleteFolderRequest struct {
	FolderName string `json:"folder_name" binding:"required,min=1,max=255"`
}

// ShareFileRequest defines the request structure for sharing a file with a user
type ShareFileRequest struct {
	Filename         string `json:"filename" binding:"required,min=1,max=255"`
	FolderName       string `json:"folder_name" binding:"required,min=1,max=255"`
	SharedWithUserID uint   `json:"shared_with_user_id" binding:"required"`
}

// ShareFolderRequest defines the request structure for sharing a folder with a user
type ShareFolderRequest struct {
	FolderName       string `json:"folder_name" binding:"required,min=1,max=255"`
	SharedWithUserID uint   `json:"shared_with_user_id" binding:"required"`
}

// GroupShareFileRequest defines the request structure for sharing a file with a group
type GroupShareFileRequest struct {
	Filename          string `json:"filename" binding:"required,min=1,max=255"`
	FolderName        string `json:"folder_name" binding:"required,min=1,max=255"`
	SharedWithGroupID uint   `json:"shared_with_group_id" binding:"required"`
}

// GroupShareFolderRequest defines the request structure for sharing a folder with a group
type GroupShareFolderRequest struct {
	FolderName        string `json:"folder_name" binding:"required,min=1,max=255"`
	SharedWithGroupID uint   `json:"shared_with_group_id" binding:"required"`
}

// CreateGroupRequest defines the request structure for creating a user group
type CreateGroupRequest struct {
	Name        string `json:"name" binding:"required,min=1,max=50"`
	Description string `json:"description" binding:"max=255"`
}

// AddGroupMemberRequest defines the request structure for adding a user to a group
type AddGroupMemberRequest struct {
	GroupID uint `json:"group_id" binding:"required"`
	UserID  uint `json:"user_id" binding:"required"`
	IsAdmin bool `json:"is_admin"`
}

// RemoveGroupMemberRequest defines the request structure for removing a user from a group
type RemoveGroupMemberRequest struct {
	GroupID uint `json:"group_id" binding:"required"`
	UserID  uint `json:"user_id" binding:"required"`
}

// TerminateSessionRequest defines the request structure for terminating a user session
type TerminateSessionRequest struct {
	SessionID string `json:"session_id" binding:"required,min=1,max=255"`
}

// ScanFileRequest defines the request structure for initiating a file scan
type ScanFileRequest struct {
	Filename   string `json:"filename" binding:"required,min=1,max=255"`
	FolderName string `json:"folder_name" binding:"required,min=1,max=255"`
	ScanType   string `json:"scan_type" binding:"required,oneof=antivirus malware"`
}

type CheckUsernameAvailabilityRequest struct {
	Username string `json:"username" binding:"required,min=3,max=50"`
}

type DownloadFolderRequest struct {
	FolderName string `json:"folder_name" binding:"required,min=1,max=255"`
}
