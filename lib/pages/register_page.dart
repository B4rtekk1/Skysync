import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import '../utils/custom_widgets.dart';
import '../utils/error_handler.dart';
import 'login_page.dart';
import 'verification_page.dart';
import 'dart:convert';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isUsernameValid = false;
  bool _isEmailValid = false;
  bool _isPasswordValid = false;
  bool _isConfirmPasswordValid = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  
  // Password validation states
  bool _hasMinLength = false;
  bool _hasMaxLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;
  bool _noRepeatedChars = false;
  bool _noSequentialPatterns = false;
  bool _noCommonWords = false;
  
  String _errorMessage = '';

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
    _slideController.forward();
    
    // Validation listeners
    _usernameController.addListener(() {
      setState(() {
        _isUsernameValid = _usernameController.text.length >= 3 && 
                          _usernameController.text.length <= 50 &&
                          RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(_usernameController.text) &&
                          !_usernameController.text.contains('@');
      });
    });
    
    _emailController.addListener(() {
      setState(() {
        _isEmailValid = _emailController.text.contains('@') && 
                       _emailController.text.contains('.');
      });
    });
    
    _passwordController.addListener(() {
      setState(() {
        _checkPassword();
      });
    });
    
    _confirmPasswordController.addListener(() {
      setState(() {
        _isConfirmPasswordValid = _confirmPasswordController.text == _passwordController.text;
      });
    });
  }

  void _checkPassword() {
    final password = _passwordController.text;
    
    _hasMinLength = password.length >= 12;
    _hasMaxLength = password.length <= 128;
    _hasUppercase = password.contains(RegExp(r'[A-Z]'));
    _hasLowercase = password.contains(RegExp(r'[a-z]'));
    _hasNumber = password.contains(RegExp(r'[0-9]'));
    _hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    _noRepeatedChars = !_hasRepeatedChars(password);
    _noSequentialPatterns = !_hasSequentialPatterns(password);
    _noCommonWords = !_hasCommonWords(password);
    
    _isPasswordValid = _hasMinLength && _hasMaxLength && _hasUppercase && 
                       _hasLowercase && _hasNumber && _hasSpecial && 
                       _noRepeatedChars && _noSequentialPatterns && _noCommonWords;
  }

  bool _hasRepeatedChars(String password) {
    for (int i = 0; i < password.length - 1; i++) {
      if (password[i] == password[i + 1]) {
        return true;
      }
    }
    return false;
  }

  bool _hasSequentialPatterns(String password) {
    // Check for sequential numbers (123, 321, etc.)
    for (int i = 0; i < password.length - 2; i++) {
      int a = password.codeUnitAt(i);
      int b = password.codeUnitAt(i + 1);
      int c = password.codeUnitAt(i + 2);
      
      if ((b == a + 1 && c == b + 1) || (b == a - 1 && c == b - 1)) {
        return true;
      }
    }
    return false;
  }

  bool _hasCommonWords(String password) {
    final commonWords = [
      'password', '123456', 'qwerty', 'admin', 'user', 'login', 'welcome',
      'haslo', 'admin123', 'user123', 'test', 'demo', 'guest', 'root',
      'password123', 'admin123', 'user123', 'test123', 'demo123'
    ];
    
    final lowerPassword = password.toLowerCase();
    return commonWords.any((word) => lowerPassword.contains(word));
  }



  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      String username = _usernameController.text.trim();
      String email = _emailController.text.trim();
      String password = _passwordController.text;

      final response = await ApiService.registerUser(
        username: username,
        email: email,
        password: password,
      );

      if (response.statusCode == 200) {
        // Navigate to verification page
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationPage(email: email),
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _errorMessage = errorData['detail'] ?? 'register.error_occurred'.tr();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = ErrorHandler.handleError(e, StackTrace.current).message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFFf093fb),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                                         const SizedBox(height: 10),
                     
                     // Header with logo and title
                     FadeTransition(
                       opacity: _fadeAnimation,
                       child: Column(
                         children: [
                                                       Image.asset(
                              'assets/Logo-name.png',
                              width: 220,
                              fit: BoxFit.contain,
                            ),
                           const SizedBox(height: 16),
                          Text(
                            'register.title'.tr(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'register.subtitle'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Registration form
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Username field
                              _buildInputField(
                                controller: _usernameController,
                                label: 'register.username'.tr(),
                                icon: Icons.person,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'register.username_required'.tr();
                                  }
                                  if (value.length < 3) {
                                    return 'register.username_min_length'.tr();
                                  }
                                  if (value.length > 50) {
                                    return 'register.username_max_length'.tr();
                                  }
                                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                                    return 'register.username_invalid_chars'.tr();
                                  }
                                  if (value.contains('@')) {
                                    return 'register.username_no_at'.tr();
                                  }
                                  return null;
                                },
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Email field
                              _buildInputField(
                                controller: _emailController,
                                label: 'register.email'.tr(),
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'register.email_required'.tr();
                                  }
                                  if (!_isEmailValid) {
                                    return 'register.invalid_email'.tr();
                                  }
                                  return null;
                                },
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Password field
                              _buildInputField(
                                controller: _passwordController,
                                label: 'register.password'.tr(),
                                icon: Icons.lock,
                                obscureText: !_isPasswordVisible,
                                suffixIcon: IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                      color: Colors.grey.shade600,
                                      size: 16,
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'register.password_required'.tr();
                                  }
                                  if (!_isPasswordValid) {
                                    return 'register.password_requirements'.tr();
                                  }
                                  return null;
                                },
                              ),
                              
                                                             // Password requirements indicator
                               if (_passwordController.text.isNotEmpty) ...[
                                 const SizedBox(height: 16),
                                 Container(
                                   padding: const EdgeInsets.all(16),
                                   decoration: BoxDecoration(
                                     gradient: LinearGradient(
                                       colors: [
                                         Colors.grey.shade50,
                                         Colors.grey.shade100,
                                       ],
                                     ),
                                     borderRadius: BorderRadius.circular(16),
                                     border: Border.all(
                                       color: Colors.grey.shade200,
                                       width: 1,
                                     ),
                                   ),
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Row(
                                         children: [
                                           Icon(
                                             Icons.security,
                                             color: const Color(0xFF764ba2),
                                             size: 20,
                                           ),
                                           const SizedBox(width: 8),
                                           Text(
                                             'register.password_requirements_title'.tr(),
                                             style: const TextStyle(
                                               fontWeight: FontWeight.bold,
                                               color: Color(0xFF764ba2),
                                             ),
                                           ),
                                         ],
                                       ),
                                       const SizedBox(height: 12),
                                       _buildRequirement('register.min_12_chars'.tr(), _hasMinLength),
                                       _buildRequirement('register.max_128_chars'.tr(), _hasMaxLength),
                                       _buildRequirement('register.uppercase'.tr(), _hasUppercase),
                                       _buildRequirement('register.lowercase'.tr(), _hasLowercase),
                                       _buildRequirement('register.number'.tr(), _hasNumber),
                                       _buildRequirement('register.special_char'.tr(), _hasSpecial),
                                       _buildRequirement('register.no_repeated_chars'.tr(), _noRepeatedChars),
                                       _buildRequirement('register.no_sequential_patterns'.tr(), _noSequentialPatterns),
                                       _buildRequirement('register.no_common_words'.tr(), _noCommonWords),
                                     ],
                                   ),
                                 ),
                               ],
                              
                              const SizedBox(height: 20),
                              
                              // Confirm password field
                              _buildInputField(
                                controller: _confirmPasswordController,
                                label: 'register.confirm_password'.tr(),
                                icon: Icons.lock_outline,
                                obscureText: !_isConfirmPasswordVisible,
                                suffixIcon: IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                      color: Colors.grey.shade600,
                                      size: 16,
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'register.confirm_password_required'.tr();
                                  }
                                  if (value != _passwordController.text) {
                                    return 'register.passwords_no_match'.tr();
                                  }
                                  return null;
                                },
                              ),
                              
                              // Password match indicator
                              if (_confirmPasswordController.text.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isConfirmPasswordValid ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _isConfirmPasswordValid ? Colors.green.shade200 : Colors.red.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isConfirmPasswordValid ? Icons.check_circle : Icons.error,
                                        color: _isConfirmPasswordValid ? Colors.green : Colors.red,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isConfirmPasswordValid 
                                          ? 'register.passwords_match'.tr()
                                          : 'register.passwords_no_match'.tr(),
                                        style: TextStyle(
                                          color: _isConfirmPasswordValid ? Colors.green : Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              
                              const SizedBox(height: 32),
                              
                              // Error message
                              if (_errorMessage.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.red.shade50,
                                        Colors.red.shade100,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.error_outline,
                                          color: Colors.red.shade600,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _errorMessage,
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                              
                              // Register button
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF764ba2).withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading || !_isUsernameValid || !_isEmailValid || !_isPasswordValid || !_isConfirmPasswordValid
                                      ? null
                                      : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF764ba2),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.person_add, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              'register.button'.tr(),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Login link
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'register.already_account'.tr(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              backgroundColor: Colors.white.withOpacity(0.15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: Text(
                              'register.login_button'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF764ba2).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
             child: TextFormField(
         controller: controller,
         obscureText: obscureText,
         keyboardType: keyboardType,
         cursorColor: const Color(0xFF764ba2),
         style: const TextStyle(
           fontSize: 16,
           fontWeight: FontWeight.w500,
         ),
                 decoration: InputDecoration(
           labelText: label,
           labelStyle: TextStyle(
             color: Colors.grey.shade600,
             fontWeight: FontWeight.w500,
           ),
           prefixIcon: Container(
             margin: const EdgeInsets.all(12),
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: const Color(0xFF764ba2).withOpacity(0.1),
               borderRadius: BorderRadius.circular(12),
             ),
             child: Icon(
               icon,
               color: const Color(0xFF764ba2),
               size: 20,
             ),
           ),
           suffixIcon: suffixIcon,
           border: OutlineInputBorder(
             borderRadius: BorderRadius.circular(16),
             borderSide: BorderSide.none,
           ),
           focusedBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(16),
             borderSide: const BorderSide(
               color: Color(0xFF764ba2),
               width: 2,
             ),
           ),
           filled: true,
           fillColor: Colors.grey.shade50,
           contentPadding: const EdgeInsets.symmetric(
             horizontal: 20,
             vertical: 16,
           ),
         ),
        validator: validator,
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isMet ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              isMet ? Icons.check : Icons.close,
              color: isMet ? Colors.green : Colors.red,
              size: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isMet ? Colors.green.shade700 : Colors.red.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
