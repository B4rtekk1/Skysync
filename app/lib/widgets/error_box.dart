import 'package:flutter/material.dart';

class ErrorBox {
  static Future<void> show(
    BuildContext context, {
    required String message,
    String? title,
    IconData? icon,
    VoidCallback? onRetry,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => _ErrorDialog(
            title: title ?? 'Error',
            message: message,
            icon: icon ?? Icons.error_outline,
            onRetry: onRetry,
          ),
    );
  }

  static Future<void> showSuccess(
    BuildContext context, {
    required String message,
    String? title,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => _ErrorDialog(
            title: title ?? 'Success',
            message: message,
            icon: Icons.check_circle_outline,
            isSuccess: true,
          ),
    );
  }

  static Future<void> showWarning(
    BuildContext context, {
    required String message,
    String? title,
    VoidCallback? onConfirm,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => _ErrorDialog(
            title: title ?? 'Warning',
            message: message,
            icon: Icons.warning_amber_rounded,
            isWarning: true,
            onRetry: onConfirm,
          ),
    );
  }

  static Future<void> showInfo(
    BuildContext context, {
    required String message,
    String? title,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => _ErrorDialog(
            title: title ?? 'Info',
            message: message,
            icon: Icons.info_outline,
            isInfo: true,
          ),
    );
  }
}

class _ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final bool isSuccess;
  final bool isWarning;
  final bool isInfo;

  const _ErrorDialog({
    required this.title,
    required this.message,
    required this.icon,
    this.onRetry,
    this.isSuccess = false,
    this.isWarning = false,
    this.isInfo = false,
  });

  Color get _primaryColor {
    if (isSuccess) return Colors.green;
    if (isWarning) return Colors.orange;
    if (isInfo) return Colors.blue;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryColor.withValues(alpha: 0.1),
                    _primaryColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 48, color: _primaryColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onRetry != null) ...[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onRetry?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isWarning ? 'Confirm' : 'Retry',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
