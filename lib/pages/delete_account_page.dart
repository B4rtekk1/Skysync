import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/custom_widgets.dart';
import '../utils/api_service.dart';
import 'package:easy_localization/easy_localization.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeletePasswordPageState();
}

class _DeletePasswordPageState extends State<DeleteAccountPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;
  bool _showTokenInput = false;
  String _sentToEmail = '';

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDeletePassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('delete.enter_email'.tr())),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.deleteAccount(email: _emailController.text);
      
      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('delete.instructions_sent'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        
        setState(() {
          _sentToEmail = _emailController.text;
          _showTokenInput = true;
          _isLoading = false;
        });
      } else {
        final data = jsonDecode(response.body);
        String errorMessage = 'delete.error_occurred'.tr();
        
        if (response.statusCode == 429) {
          errorMessage = 'delete.too_many_attempts'.tr();
        } else if (data['detail']) {
          errorMessage = data['detail'];
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('delete.error_occurred'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleTokenSubmit() async {
    if (_tokenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('delete.enter_token'.tr())),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.confirmDelete(token: _tokenController.text);
      
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('delete.account_deleted_successfully'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to login page after successful account deletion
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        final data = jsonDecode(response.body);
        String errorMessage = 'delete.error_occurred'.tr();
        
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
          content: Text('delete.error_occurred'.tr()),
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
          ),
        ),
        child: SafeArea(
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
                              _showTokenInput ? 'delete.enter_token_title'.tr() : 'delete.reset_title'.tr(),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showTokenInput 
                                ? 'delete.enter_token_desc'.tr()
                                : 'delete.enter_email_desc'.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 30),
                            // Email input (shown when not showing token input)
                            if (!_showTokenInput) ...[
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 200),
                                child: SizedBox(
                                  width: width,
                                  child: UsernameField(
                                    controller: _emailController,
                                    labelText: 'delete.email'.tr(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 200),
                                child: SizedBox(
                                  width: width,
                                  child: AnimatedButton(
                                    text: 'delete.send_token'.tr(),
                                    onPressed: _handleDeletePassword,
                                    isLoading: _isLoading,
                                  ),
                                ),
                              ),
                            ],
                            // Token input (shown when showing token input)
                            if (_showTokenInput) ...[
                              // Show email info
                              Container(
                                width: width,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFF764ba2)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Color(0xFF764ba2), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'delete.token_sent'.tr(namedArgs: {'email': _sentToEmail}),
                                        style: TextStyle(
                                          color: const Color(0xFF764ba2),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 200),
                                child: SizedBox(
                                  width: width,
                                  child: TextField(
                                    controller: _tokenController,
                                    decoration: InputDecoration(
                                      labelText: 'delete.token_label'.tr(),
                                      hintText: 'delete.token_hint'.tr(),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 200),
                                child: SizedBox(
                                  width: width,
                                  child: AnimatedButton(
                                    text: 'delete.delete_account_button'.tr(),
                                    onPressed: _handleTokenSubmit,
                                    isLoading: _isLoading,
                                  ),
                                ),
                              ),
                            ],
                            // Back button (shown when showing token input)
                            if (_showTokenInput) ...[
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showTokenInput = false;
                                    _tokenController.clear();
                                  });
                                },
                                child: Text(
                                  'delete.back_to_email'.tr(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    'delete.back_to_login'.tr(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
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
      ),
    );
  }
}