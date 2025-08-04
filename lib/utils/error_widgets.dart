import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'error_handler.dart';

class RetryableErrorWidget extends StatelessWidget {
  final AppError error;
  final VoidCallback onRetry;
  final String? customMessage;

  const RetryableErrorWidget({
    super.key,
    required this.error,
    required this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
                         Icon(
               ErrorHandler.getErrorIcon(error.type),
               size: 64,
               color: ErrorHandler.getErrorColor(error.type),
             ),
            const SizedBox(height: 16),
            Text(
              customMessage ?? error.message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (error.code != null)
              Text(
                'error.code'.tr(args: [error.code!]),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            if (ErrorHandler.isRetryable(error.type))
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text('common.retry'.tr()),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ErrorHandler.showErrorDialog(context, error);
              },
              child: Text('error.more_details'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;

  const NetworkErrorWidget({
    super.key,
    required this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return RetryableErrorWidget(
      error: AppError(
        message: message ?? 'error.network_connection'.tr(),
        type: ErrorType.network,
      ),
      onRetry: onRetry,
    );
  }
}

class LoadingErrorWidget extends StatelessWidget {
  final AppError error;
  final VoidCallback onRetry;
  final String? title;

  const LoadingErrorWidget({
    super.key,
    required this.error,
    required this.onRetry,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'error.title'.tr()),
      ),
      body: RetryableErrorWidget(
        error: error,
        onRetry: onRetry,
      ),
    );
  }
}

class ErrorSnackBar extends SnackBar {
  ErrorSnackBar({
    super.key,
    required AppError error,
    VoidCallback? onRetry,
  }) : super(
          content: Row(
            children: [
              Icon(
                ErrorHandler.getErrorIcon(error.type),
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(error.message)),
            ],
          ),
          backgroundColor: ErrorHandler.getErrorColor(error.type),
          duration: const Duration(seconds: 4),
          action: onRetry != null && ErrorHandler.isRetryable(error.type)
              ? SnackBarAction(
                  label: 'common.retry'.tr(),
                  textColor: Colors.white,
                  onPressed: onRetry,
                )
              : SnackBarAction(
                  label: 'common.dismiss'.tr(),
                  textColor: Colors.white,
                  onPressed: () {},
                ),
        );
}

class ErrorDialog extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ErrorDialog({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            ErrorHandler.getErrorIcon(error.type),
            color: ErrorHandler.getErrorColor(error.type),
          ),
          const SizedBox(width: 8),
          Text('error.title'.tr()),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error.message),
          if (error.code != null) ...[
            const SizedBox(height: 8),
            Text(
              'error.code'.tr(args: [error.code!]),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (error.originalError != null) ...[
            const SizedBox(height: 8),
            Text(
              'error.technical_details'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (onDismiss != null)
          TextButton(
            onPressed: onDismiss,
            child: Text('common.cancel'.tr()),
          ),
        if (onRetry != null && ErrorHandler.isRetryable(error.type))
          ElevatedButton(
            onPressed: onRetry,
            child: Text('common.retry'.tr()),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.ok'.tr()),
        ),
      ],
    );
  }
}

class ErrorBanner extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ErrorBanner({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: ErrorHandler.getErrorColor(error.type),
      child: Row(
        children: [
          Icon(
            ErrorHandler.getErrorIcon(error.type),
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error.message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (onRetry != null && ErrorHandler.isRetryable(error.type))
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              child: Text('common.retry'.tr()),
            ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, color: Colors.white),
              iconSize: 20,
            ),
        ],
      ),
    );
  }
} 

class EnhancedErrorNotification extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final Duration duration;
  final bool autoDismiss;

  const EnhancedErrorNotification({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.duration = const Duration(seconds: 5),
    this.autoDismiss = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: ErrorHandler.getErrorColor(error.type).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: ErrorHandler.getErrorColor(error.type).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ErrorHandler.getErrorColor(error.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      ErrorHandler.getErrorIcon(error.type),
                      color: ErrorHandler.getErrorColor(error.type),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getErrorTitle(error.type),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: ErrorHandler.getErrorColor(error.type),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          error.message,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onDismiss != null)
                    IconButton(
                      onPressed: onDismiss,
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey.shade500,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              if (onRetry != null && ErrorHandler.isRetryable(error.type)) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text('common.retry'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ErrorHandler.getErrorColor(error.type),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getErrorTitle(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'error.network_title'.tr();
      case ErrorType.authentication:
        return 'error.auth_title'.tr();
      case ErrorType.authorization:
        return 'error.access_title'.tr();
      case ErrorType.validation:
        return 'error.validation_title'.tr();
      case ErrorType.server:
        return 'error.server_title'.tr();
      case ErrorType.file:
        return 'error.file_title'.tr();
      case ErrorType.unknown:
        return 'error.unknown_title'.tr();
    }
  }
}

class FloatingErrorBanner extends StatefulWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final Duration duration;

  const FloatingErrorBanner({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<FloatingErrorBanner> createState() => _FloatingErrorBannerState();
}

class _FloatingErrorBannerState extends State<FloatingErrorBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();

    if (widget.duration != Duration.zero) {
      Future.delayed(widget.duration, () {
        if (mounted) {
          _dismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 100),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ErrorHandler.getErrorColor(widget.error.type),
                    ErrorHandler.getErrorColor(widget.error.type).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: ErrorHandler.getErrorColor(widget.error.type).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.error.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            if (widget.error.code != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'error.code'.tr(args: [widget.error.code!]),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.onRetry != null && ErrorHandler.isRetryable(widget.error.type))
                        IconButton(
                          onPressed: widget.onRetry,
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      IconButton(
                        onPressed: _dismiss,
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SuccessNotification extends StatelessWidget {
  final String message;
  final String? title;
  final IconData? icon;
  final VoidCallback? onDismiss;
  final Duration duration;

  const SuccessNotification({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.onDismiss,
    this.duration = const Duration(seconds: 3),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: const Color(0xFF667eea).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon ?? Icons.check_circle,
                  color: const Color(0xFF667eea),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF667eea),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoNotification extends StatelessWidget {
  final String message;
  final String? title;
  final IconData? icon;
  final VoidCallback? onDismiss;
  final Duration duration;

  const InfoNotification({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.onDismiss,
    this.duration = const Duration(seconds: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon ?? Icons.info,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 