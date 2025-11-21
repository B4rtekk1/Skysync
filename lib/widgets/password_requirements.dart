import 'package:flutter/material.dart';
import '../utils/validators.dart';

class PasswordRequirements extends StatelessWidget {
  final String password;

  const PasswordRequirements({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password Requirements:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        _buildRequirement('At least 12 characters', hasValidLength(password)),
        _buildRequirement(
          'At least one uppercase letter',
          hasUppercase(password),
        ),
        _buildRequirement(
          'At least one lowercase letter',
          hasLowercase(password),
        ),
        _buildRequirement('At least one number', hasNumber(password)),
        _buildRequirement(
          'At least one special character',
          hasSpecialChar(password),
        ),
        _buildRequirement(
          'No repeated characters (3+)',
          !hasRepeatedChars(password) && password.isNotEmpty,
        ),
      ],
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isMet ? Colors.green : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
