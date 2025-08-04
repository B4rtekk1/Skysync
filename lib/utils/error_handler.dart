import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
import 'dart:async';

enum ErrorType {
  network,
  authentication,
  authorization,
  validation,
  server,
  file,
  unknown,
}

class AppError {
  final String message;
  final ErrorType type;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppError({
    required this.message,
    required this.type,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'AppError($type): $message';
}

class ErrorHandler {
  static AppError handleError(dynamic error, StackTrace? stackTrace) {
    if (error is AppError) {
      return error;
    }

    if (error is SocketException) {
      return AppError(
        message: 'error.network_connection'.tr(),
        type: ErrorType.network,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (error is HttpException) {
      return AppError(
        message: 'error.http_exception'.tr(),
        type: ErrorType.network,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return AppError(
        message: 'error.data_format'.tr(),
        type: ErrorType.validation,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (error is TimeoutException) {
      return AppError(
        message: 'error.timeout'.tr(),
        type: ErrorType.network,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Domyślny błąd
    return AppError(
      message: 'error.unknown'.tr(),
      type: ErrorType.unknown,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  static AppError handleHttpError(int statusCode, String responseBody) {
    switch (statusCode) {
      case 400:
        return AppError(
          message: 'error.bad_request'.tr(),
          type: ErrorType.validation,
          code: statusCode.toString(),
        );
      case 401:
        return AppError(
          message: 'error.unauthorized'.tr(),
          type: ErrorType.authentication,
          code: statusCode.toString(),
        );
      case 403:
        return AppError(
          message: 'error.forbidden'.tr(),
          type: ErrorType.authorization,
          code: statusCode.toString(),
        );
      case 404:
        return AppError(
          message: 'error.not_found'.tr(),
          type: ErrorType.server,
          code: statusCode.toString(),
        );
      case 409:
        return AppError(
          message: 'error.conflict'.tr(),
          type: ErrorType.validation,
          code: statusCode.toString(),
        );
      case 422:
        return AppError(
          message: 'error.validation_failed'.tr(),
          type: ErrorType.validation,
          code: statusCode.toString(),
        );
      case 429:
        return AppError(
          message: 'error.too_many_requests'.tr(),
          type: ErrorType.server,
          code: statusCode.toString(),
        );
      case 500:
        return AppError(
          message: 'error.internal_server'.tr(),
          type: ErrorType.server,
          code: statusCode.toString(),
        );
      case 502:
      case 503:
      case 504:
        return AppError(
          message: 'error.service_unavailable'.tr(),
          type: ErrorType.server,
          code: statusCode.toString(),
        );
      default:
        return AppError(
          message: 'error.http_error'.tr(args: [statusCode.toString()]),
          type: ErrorType.server,
          code: statusCode.toString(),
        );
    }
  }

  static void showErrorDialog(BuildContext context, AppError error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
                             Icon(
                 getErrorIcon(error.type),
                 color: getErrorColor(error.type),
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('common.ok'.tr()),
            ),
            if (error.type == ErrorType.authentication)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: Text('error.login_again'.tr()),
              ),
          ],
        );
      },
    );
  }

  static void showErrorSnackBar(BuildContext context, AppError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
                         Icon(
               getErrorIcon(error.type),
               color: Colors.white,
               size: 20,
             ),
            const SizedBox(width: 8),
            Expanded(child: Text(error.message)),
          ],
        ),
                 backgroundColor: getErrorColor(error.type),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'common.dismiss'.tr(),
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static IconData getErrorIcon(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.authentication:
        return Icons.lock;
      case ErrorType.authorization:
        return Icons.block;
      case ErrorType.validation:
        return Icons.warning;
      case ErrorType.server:
        return Icons.error;
      case ErrorType.file:
        return Icons.file_present;
      case ErrorType.unknown:
        return Icons.help;
    }
  }

  static Color getErrorColor(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Colors.orange;
      case ErrorType.authentication:
        return Colors.red;
      case ErrorType.authorization:
        return Colors.red;
      case ErrorType.validation:
        return Colors.orange;
      case ErrorType.server:
        return Colors.red;
      case ErrorType.file:
        return Colors.blue;
      case ErrorType.unknown:
        return Colors.grey;
    }
  }

  static String getRetryMessage(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'error.retry_network'.tr();
      case ErrorType.server:
        return 'error.retry_server'.tr();
      case ErrorType.file:
        return 'error.retry_file'.tr();
      default:
        return 'error.retry_general'.tr();
    }
  }

  static bool isRetryable(ErrorType type) {
    return type == ErrorType.network || 
           type == ErrorType.server || 
           type == ErrorType.file;
  }
}

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(AppError error)? errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  AppError? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error!);
      }
      
      return _buildDefaultErrorWidget();
    }

    return widget.child;
  }

  Widget _buildDefaultErrorWidget() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'error.something_went_wrong'.tr(),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error?.message ?? 'error.unknown'.tr(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                  });
                },
                child: Text('error.try_again'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 