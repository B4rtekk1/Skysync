import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/error_handler.dart';
import '../utils/error_widgets.dart';

class ErrorDemoPage extends StatelessWidget {
  const ErrorDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('error.demo.title'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'error.demo.description'.tr(),
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Przykłady różnych typów błędów
            _buildErrorButton(
              context,
              'error.demo.network_error'.tr(),
              () => _showNetworkError(context),
              Icons.wifi_off,
              Colors.orange,
            ),
            
            _buildErrorButton(
              context,
              'error.demo.auth_error'.tr(),
              () => _showAuthError(context),
              Icons.lock,
              Colors.red,
            ),
            
            _buildErrorButton(
              context,
              'error.demo.server_error'.tr(),
              () => _showServerError(context),
              Icons.error,
              Colors.red,
            ),
            
            _buildErrorButton(
              context,
              'error.demo.validation_error'.tr(),
              () => _showValidationError(context),
              Icons.warning,
              Colors.orange,
            ),
            
            _buildErrorButton(
              context,
              'error.demo.file_error'.tr(),
              () => _showFileError(context),
              Icons.file_present,
              Colors.blue,
            ),
            
            const SizedBox(height: 24),
            
            // Przykłady widgetów błędów
            Text(
              'error.demo.widgets'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: () => _showErrorWidget(context),
              child: Text('error.demo.show_error_widget'.tr()),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: () => _showErrorBanner(context),
              child: Text('error.demo.show_error_banner'.tr()),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: () => _showErrorSnackBar(context),
              child: Text('error.demo.show_error_snackbar'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorButton(
    BuildContext context,
    String title,
    VoidCallback onPressed,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _showNetworkError(BuildContext context) {
    final error = AppError(
      message: 'error.network_connection'.tr(),
      type: ErrorType.network,
    );
    ErrorHandler.showErrorDialog(context, error);
  }

  void _showAuthError(BuildContext context) {
    final error = AppError(
      message: 'error.unauthorized'.tr(),
      type: ErrorType.authentication,
      code: '401',
    );
    ErrorHandler.showErrorDialog(context, error);
  }

  void _showServerError(BuildContext context) {
    final error = AppError(
      message: 'error.internal_server'.tr(),
      type: ErrorType.server,
      code: '500',
    );
    ErrorHandler.showErrorDialog(context, error);
  }

  void _showValidationError(BuildContext context) {
    final error = AppError(
      message: 'error.validation_failed'.tr(),
      type: ErrorType.validation,
      code: '422',
    );
    ErrorHandler.showErrorDialog(context, error);
  }

  void _showFileError(BuildContext context) {
    final error = AppError(
      message: 'error.file_not_found'.tr(),
      type: ErrorType.file,
      code: '404',
    );
    ErrorHandler.showErrorDialog(context, error);
  }

  void _showErrorWidget(BuildContext context) {
    final error = AppError(
      message: 'error.demo.widget_error'.tr(),
      type: ErrorType.network,
    );
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: RetryableErrorWidget(
            error: error,
            onRetry: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('error.demo.retry_clicked'.tr())),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showErrorBanner(BuildContext context) {
    final error = AppError(
      message: 'error.demo.banner_error'.tr(),
      type: ErrorType.server,
    );
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ErrorBanner(
              error: error,
              onRetry: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('error.demo.retry_clicked'.tr())),
                );
              },
              onDismiss: () => Navigator.of(context).pop(),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Treść dialogu...'),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context) {
    final error = AppError(
      message: 'error.demo.snackbar_error'.tr(),
      type: ErrorType.validation,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      ErrorSnackBar(
        error: error,
        onRetry: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('error.demo.retry_clicked'.tr())),
          );
        },
      ),
    );
  }
} 