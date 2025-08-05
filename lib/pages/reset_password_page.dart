import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/custom_widgets.dart';
import '../utils/api_service.dart';
import 'package:easy_localization/easy_localization.dart';

class ResetPasswordPage extends StatefulWidget {
  final String token;
  
  const ResetPasswordPage({super.key, required this.token});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isValidToken = false;
  bool _isValidatingToken = true;
  
  // Password validation state variables
  bool _hasMinLength = false; // Min. 12 characters
  bool _hasMaxLength = false; // Max. 128 characters
  bool _hasUppercase = false; // At least one uppercase letter
  bool _hasLowercase = false; // At least one lowercase letter
  bool _hasNumber = false; // At least one digit
  bool _hasSpecial = false; // At least one special character
  bool _noRepeatedChars = false; // No repeated characters more than 2 times
  bool _noSequentialPatterns = false; // No sequential patterns
  bool _noCommonWords = false; // No common words
  bool _isPasswordMatch = false;

  @override
  void initState() {
    super.initState();
    _validateToken();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _validateToken() async {
    try {
      final response = await ApiService.validateResetToken(token: widget.token);
      
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isValidToken = data['valid'] == true;
          _isValidatingToken = false;
        });
      } else {
        setState(() {
          _isValidToken = false;
          _isValidatingToken = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidToken = false;
        _isValidatingToken = false;
      });
    }
  }

  String getPasswordStrength(String password) {
    int score = 0;
    if (password.length >= 12) score++; // Updated from 8 to 12
    if (password.length <= 128) score++; // New: Max length
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++; // New: Lowercase
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=~`]').hasMatch(password)) score++; // Updated special chars
    if (!RegExp(r'(.)\1{2,}').hasMatch(password)) score++; // New: No repeated chars
    if (!_hasSequentialPatterns(password)) score++; // New: No sequential patterns
    if (!_hasCommonWords(password)) score++; // New: No common words

    if (score <= 3) return 'Very weak'; // Adjusted score thresholds
    if (score <= 5) return 'Weak';
    if (score <= 7) return 'Medium';
    if (score <= 8) return 'Strong';
    return 'Very strong';
  }

  // New helper function for sequential patterns
  bool _hasSequentialPatterns(String password) {
    final patterns = [
      'abc', 'bcd', 'cde', 'def', 'efg', 'fgh', 'ghi', 'hij', 'ijk', 'jkl', 'klm', 'lmn', 'mno', 'nop', 'opq', 'pqr', 'qrs', 'rst', 'stu', 'tuv', 'uvw', 'vwx', 'wxy', 'xyz',
      '123', '234', '345', '456', '567', '678', '789', '012'
    ];
    final lowerPassword = password.toLowerCase();
    return patterns.any((pattern) => lowerPassword.contains(pattern));
  }

  // New helper function for common words
  bool _hasCommonWords(String password) {
    final commonWords = [
      'password', 'admin', 'user', 'test', 'guest', 'qwerty', 'asdfgh', 'zxcvbn', '123456', '654321'
    ];
    final lowerPassword = password.toLowerCase();
    return commonWords.any((word) => lowerPassword.contains(word));
  }

  Color _getPasswordStrengthColor(String password) {
    int score = 0;
    if (password.length >= 12) score++; // Updated from 8 to 12
    if (password.length <= 128) score++; // New: Max length
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++; // New: Lowercase
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=~`]').hasMatch(password)) score++; // Updated special chars
    if (!RegExp(r'(.)\1{2,}').hasMatch(password)) score++; // New: No repeated chars
    if (!_hasSequentialPatterns(password)) score++; // New: No sequential patterns
    if (!_hasCommonWords(password)) score++; // New: No common words

    if (score <= 3) return Colors.red; // Adjusted score thresholds
    if (score <= 5) return Colors.orange;
    if (score <= 7) return Colors.yellow;
    if (score <= 8) return Colors.lightGreen;
    return Colors.green;
  }

  void _checkPassword(String password) {
    setState(() {
      _hasMinLength = password.length >= 12; // Updated from 8 to 12
      _hasMaxLength = password.length <= 128; // New check
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]')); // New check
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecial = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=~`]')); // Updated special chars
      _noRepeatedChars = !RegExp(r'(.)\1{2,}').hasMatch(password); // New check
      _noSequentialPatterns = !_hasSequentialPatterns(password); // New check
      _noCommonWords = !_hasCommonWords(password); // New check
      _isPasswordMatch = _passwordController.text == _confirmPasswordController.text && 
                         _passwordController.text.isNotEmpty;
    });
  }

  bool _getPasswordsMatch() {
    return _passwordController.text == _confirmPasswordController.text && 
           _passwordController.text.isNotEmpty;
  }

  Future<void> _handleResetPassword() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reset.enter_password'.tr())),
      );
      return;
    }

    if (!_getPasswordsMatch()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reset.passwords_no_match'.tr())),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.confirmReset(
        token: widget.token,
        newPassword: _passwordController.text,
      );
      
      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('reset.password_reset_success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        
        // Przejdź do strony logowania
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        final data = jsonDecode(response.body);
        String errorMessage = 'reset.error_occurred'.tr();
        
        if (data['detail']) {
          errorMessage = data['detail'];
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('reset.error_occurred'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isValidatingToken) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'reset.validating'.tr(),
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isValidToken) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'reset.invalid_link'.tr(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'reset.invalid_link_desc'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/forgot-password', (route) => false);
                },
                child: Text('reset.request_new_link'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFf8fafc),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF667eea).withOpacity(0.1),
              const Color(0xFF764ba2).withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 50),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 256,
                    maxHeight: 256,
                  ),
                  child: Image.asset(
                    'assets/Logo-name.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 120),
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double width = constraints.maxWidth * 0.8;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'reset.set_new_password'.tr(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'reset.enter_new_password'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 30),
                          
                          // Password field
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 200),
                            child: SizedBox(
                              width: width,
                              child: TextField(
                                controller: _passwordController,
                                obscureText: !_showPassword,
                                decoration: InputDecoration(
                                  labelText: 'reset.new_password'.tr(),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPassword ? Icons.visibility : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showPassword = !_showPassword;
                                      });
                                    },
                                  ),
                                ),
                                onChanged: (value) {
                                  _checkPassword(value);
                                },
                              ),
                            ),
                          ),
                          
                          // Password requirements
                          if (_passwordController.text.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: width,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'reset.password_requirements'.tr(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _hasMinLength ? Icons.check : Icons.close,
                                            color: _hasMinLength ? Colors.green : Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('reset.min_12_chars'.tr()),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            _hasMaxLength ? Icons.check : Icons.close,
                                            color: _hasMaxLength ? Colors.green : Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('reset.max_128_chars'.tr()),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            _hasUppercase ? Icons.check : Icons.close,
                                            color: _hasUppercase ? Colors.green : Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('reset.uppercase'.tr()),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            _hasLowercase ? Icons.check : Icons.close,
                                            color: _hasLowercase ? Colors.green : Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('reset.lowercase'.tr()),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            _hasNumber ? Icons.check : Icons.close,
                                            color: _hasNumber ? Colors.green : Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('reset.number'.tr()),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            _hasSpecial ? Icons.check : Icons.close,
                                            color: _hasSpecial ? Colors.green : Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('reset.special_char'.tr()),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            _noRepeatedChars ? Icons.check : Icons.close,
                                            color: _noRepeatedChars ? Colors.green : Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('reset.no_repeated_chars'.tr()),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            _noSequentialPatterns ? Icons.check : Icons.close,
                                            color: _noSequentialPatterns ? Colors.green : Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('reset.no_sequential_patterns'.tr()),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            _noCommonWords ? Icons.check : Icons.close,
                                            color: _noCommonWords ? Colors.green : Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('reset.no_common_words'.tr()),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          
                          // Confirm password field
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 200),
                            child: SizedBox(
                              width: width,
                              child: TextField(
                                controller: _confirmPasswordController,
                                obscureText: !_showConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'reset.confirm_password'.tr(),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showConfirmPassword = !_showConfirmPassword;
                                      });
                                    },
                                  ),
                                ),
                                onChanged: (value) {
                                  _checkPassword(_passwordController.text);
                                },
                              ),
                            ),
                          ),
                          
                          // Password match indicator
                          if (_confirmPasswordController.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: width,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getPasswordsMatch() ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getPasswordsMatch() ? Colors.green : Colors.red,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _getPasswordsMatch() ? Icons.check_circle : Icons.error,
                                    color: _getPasswordsMatch() ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getPasswordsMatch() ? 'reset.passwords_match'.tr() : 'reset.passwords_no_match'.tr(),
                                    style: TextStyle(
                                      color: _getPasswordsMatch() ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 200),
                            child: SizedBox(
                              width: width,
                              child: AnimatedButton(
                                text: 'reset.reset_button'.tr(),
                                onPressed: _handleResetPassword,
                                isLoading: _isLoading,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'reset.remember_password'.tr(),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                                },
                                child: Text(
                                  'reset.back_to_login'.tr(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 