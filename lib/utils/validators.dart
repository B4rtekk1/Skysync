bool hasValidLength(String password) {
  return password.length >= 12 && password.length <= 128;
}

bool hasUppercase(String password) {
  return RegExp(r'[A-Z]').hasMatch(password);
}

bool hasLowercase(String password) {
  return RegExp(r'[a-z]').hasMatch(password);
}

bool hasNumber(String password) {
  return RegExp(r'[0-9]').hasMatch(password);
}

bool hasSpecialChar(String password) {
  return RegExp(r'[!@#\$%^&*(),.?":{}|<>_+=~-]').hasMatch(password);
}

bool hasRepeatedChars(String password) {
  if (password.isEmpty) return false;
  for (int i = 0; i < password.length - 2; i++) {
    if (password[i] == password[i + 1] && password[i] == password[i + 2]) {
      return true;
    }
  }
  return false;
}

String? validatePassword(String? password) {
  if (password == null || password.isEmpty) {
    return 'Password is required';
  }

  if (!hasValidLength(password)) {
    return 'Password must be between 12 and 128 characters';
  }

  if (!hasUppercase(password)) {
    return 'Password must contain at least one uppercase letter';
  }

  if (!hasLowercase(password)) {
    return 'Password must contain at least one lowercase letter';
  }

  if (!hasNumber(password)) {
    return 'Password must contain at least one number';
  }

  if (!hasSpecialChar(password)) {
    return 'Password must contain at least one special character';
  }

  if (hasRepeatedChars(password)) {
    return 'Password must not contain a character repeated three or more times consecutively';
  }

  return null;
}
