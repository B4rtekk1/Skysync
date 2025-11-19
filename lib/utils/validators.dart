String? validatePassword(String? password) {
  if (password == null || password.isEmpty) {
    return 'Password is required';
  }

  if (password.length < 12 || password.length > 128) {
    return 'Password must be between 12 and 128 characters';
  }

  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return 'Password must contain at least one uppercase letter';
  }

  if (!RegExp(r'[a-z]').hasMatch(password)) {
    return 'Password must contain at least one lowercase letter';
  }

  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return 'Password must contain at least one number';
  }

  if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=~]').hasMatch(password)) {
    return 'Password must contain at least one special character';
  }

  if (_hasRepeatedChars(password)) {
    return 'Password must not contain a character repeated three or more times consecutively';
  }

  if (_containsCommonPattern(password)) {
    return 'Password contains a common pattern (e.g., abc, 123)';
  }

  if (_containsCommonWord(password)) {
    return 'Password contains a common word (e.g., password, admin)';
  }

  return null;
}

bool _hasRepeatedChars(String password) {
  for (int i = 0; i < password.length - 2; i++) {
    if (password[i] == password[i + 1] && password[i] == password[i + 2]) {
      return true;
    }
  }
  return false;
}

bool _containsCommonPattern(String password) {
  final patterns = [
    "abc",
    "bcd",
    "cde",
    "def",
    "efg",
    "fgh",
    "ghi",
    "hij",
    "ijk",
    "jkl",
    "klm",
    "lmn",
    "mno",
    "nop",
    "opq",
    "pqr",
    "qrs",
    "rst",
    "stu",
    "tuv",
    "uvw",
    "vwx",
    "wxy",
    "xyz",
    "123",
    "234",
    "345",
    "456",
    "567",
    "678",
    "789",
    "012",
  ];
  String lowerPassword = password.toLowerCase();
  for (var pattern in patterns) {
    if (lowerPassword.contains(pattern)) {
      return true;
    }
  }
  return false;
}

bool _containsCommonWord(String password) {
  final commonWords = [
    "password",
    "admin",
    "user",
    "test",
    "guest",
    "qwerty",
    "asdfgh",
    "zxcvbn",
    "123456",
    "654321",
  ];
  String lowerPassword = password.toLowerCase();
  for (var word in commonWords) {
    if (lowerPassword.contains(word)) {
      return true;
    }
  }
  return false;
}
