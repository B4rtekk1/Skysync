import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import 'package:easy_localization/easy_localization.dart';

class VerificationPage extends StatefulWidget {
  final String email;
  
  const VerificationPage({super.key, required this.email});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());
  String _serverMessage = '';
  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyCode() async {
    setState(() {
      _isLoading = true;
      _serverMessage = '';
    });
    
    final code = _controllers.map((c) => c.text).join();
    
    try {
      final response = await ApiService.verifyUser(
        email: widget.email,
        code: code,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _serverMessage = 'verification.success'.tr();
        });
        
        // Po udanej weryfikacji, przekieruj do logowania z informacją o sukcesie
        Navigator.pushReplacementNamed(context, '/login', arguments: 'verified');
      } else {
        setState(() {
          _serverMessage = 'verification.failed'.tr(args: [response.body]);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverMessage = 'verification.network_error'.tr(args: [e.toString()]);
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text('verification.title'.tr(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
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
        child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('verification.enter_code'.tr(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                return Container(
                  width: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(fontSize: 24, letterSpacing: 2),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => _onChanged(i, val),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyCode,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text('verification.verify_button'.tr()),
              ),
            ),
            const SizedBox(height: 24),
            if (_serverMessage.isNotEmpty)
              Text(
                _serverMessage,
                style: TextStyle(
                  color: _serverMessage.contains('success')
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
        ),
      ),
    );
  }
}
