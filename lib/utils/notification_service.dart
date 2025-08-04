import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'error_handler.dart';
import 'error_widgets.dart';

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void showEnhancedError(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 5),
  }) {
    _showOverlayNotification(
      context,
      EnhancedErrorNotification(
        error: error,
        onRetry: onRetry,
        onDismiss: () => _hideOverlayNotification(context),
        duration: duration,
      ),
    );
  }

  static void showFloatingError(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    _showOverlayNotification(
      context,
      FloatingErrorBanner(
        error: error,
        onRetry: onRetry,
        onDismiss: () => _hideOverlayNotification(context),
        duration: duration,
      ),
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showOverlayNotification(
      context,
      SuccessNotification(
        message: message,
        title: title,
        icon: icon,
        onDismiss: () => _hideOverlayNotification(context),
        duration: duration,
      ),
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
  }) {
    _showOverlayNotification(
      context,
      InfoNotification(
        message: message,
        title: title,
        icon: icon,
        onDismiss: () => _hideOverlayNotification(context),
        duration: duration,
      ),
    );
  }

  static void showErrorDialog(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ErrorDialog(
          error: error,
          onRetry: onRetry,
          onDismiss: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  static void showLoadingDialog(
    BuildContext context,
    String message,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  static void hideLoadingDialog(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  static void _showOverlayNotification(
    BuildContext context,
    Widget notification,
  ) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: notification,
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-dismiss after duration
    Future.delayed(const Duration(seconds: 5), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  static void _hideOverlayNotification(BuildContext context) {
    // This will be called by the notification's dismiss button
    // The overlay will be removed automatically after the duration
  }

  // Convenience methods for common error scenarios
  static void showNetworkError(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    final error = AppError(
      message: 'error.network_connection'.tr(),
      type: ErrorType.network,
    );
    showFloatingError(context, error, onRetry: onRetry);
  }

  static void showAuthError(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    final error = AppError(
      message: 'error.unauthorized'.tr(),
      type: ErrorType.authentication,
    );
    showEnhancedError(context, error, onRetry: onRetry);
  }

  static void showServerError(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    final error = AppError(
      message: 'error.internal_server'.tr(),
      type: ErrorType.server,
    );
    showFloatingError(context, error, onRetry: onRetry);
  }

  static void showValidationError(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    final error = AppError(
      message: message,
      type: ErrorType.validation,
    );
    showEnhancedError(context, error, onRetry: onRetry);
  }

  static void showFileError(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    final error = AppError(
      message: message,
      type: ErrorType.file,
    );
    showFloatingError(context, error, onRetry: onRetry);
  }

  // Success notifications for common operations
  static void showFileUploaded(BuildContext context, String fileName) {
    showSuccess(
      context,
      'files.upload_success'.tr(namedArgs: {'filename': fileName}),
      title: 'files.upload_title'.tr(),
      icon: Icons.cloud_upload,
    );
  }

  static void showFileDeleted(BuildContext context, String fileName) {
    showSuccess(
      context,
      'files.delete_success'.tr(namedArgs: {'filename': fileName}),
      title: 'files.delete_title'.tr(),
      icon: Icons.delete,
    );
  }

  static void showFolderCreated(BuildContext context, String folderName) {
    showSuccess(
      context,
      'files.folder_created'.tr(namedArgs: {'foldername': folderName}),
      title: 'files.folder_created_title'.tr(),
      icon: Icons.create_new_folder,
    );
  }

  static void showFileShared(BuildContext context, String fileName, String user) {
    showSuccess(
      context,
      'share.share_success'.tr(namedArgs: {'filename': fileName, 'user': user}),
      title: 'share.share_title'.tr(),
      icon: Icons.share,
    );
  }

  static void showFileUnshared(BuildContext context, String fileName) {
    showSuccess(
      context,
      'share.unshare_success'.tr(),
      title: 'share.unshare_title'.tr(),
      icon: Icons.link_off,
    );
  }

  static void showFileDownloaded(BuildContext context, String fileName) {
    showSuccess(
      context,
      'files.download_success'.tr(namedArgs: {'filename': fileName}),
      title: 'files.download_title'.tr(),
      icon: Icons.download,
    );
  }

  static void showFileRenamed(BuildContext context, String oldName, String newName) {
    showSuccess(
      context,
      'files.rename_success'.tr(namedArgs: {'oldname': oldName, 'newname': newName}),
      title: 'files.rename_title'.tr(),
      icon: Icons.edit,
    );
  }

  static void showFileMoved(BuildContext context, String fileName) {
    showSuccess(
      context,
      'files.move_success'.tr(namedArgs: {'filename': fileName}),
      title: 'files.move_title'.tr(),
      icon: Icons.drive_file_move,
    );
  }

  static void showFileFavorited(BuildContext context, String fileName) {
    showSuccess(
      context,
      'files.favorite_added'.tr(namedArgs: {'filename': fileName}),
      title: 'files.favorite_title'.tr(),
      icon: Icons.favorite,
    );
  }

  static void showFileUnfavorited(BuildContext context, String fileName) {
    showSuccess(
      context,
      'files.favorite_removed'.tr(namedArgs: {'filename': fileName}),
      title: 'files.favorite_title'.tr(),
      icon: Icons.favorite_border,
    );
  }
} 