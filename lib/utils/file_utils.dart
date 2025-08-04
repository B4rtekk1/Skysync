class FileUtils {
  static const List<String> imageExtensions = [
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.svg'
  ];
  
  static const List<String> videoExtensions = [
    '.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.mkv', '.m4v'
  ];
  
  static const List<String> audioExtensions = [
    '.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma', '.m4a'
  ];
  
  static const List<String> documentExtensions = [
    '.pdf', '.doc', '.docx', '.rtf', '.odt', '.pages'
  ];
  
  static const List<String> textExtensions = [
    '.txt', '.md', '.py', '.js', '.html', '.css', '.json', '.xml', '.csv', '.log', '.ini', '.cfg', '.conf', '.php', '.java', '.cpp', '.c', '.h', '.sql', '.sh', '.bat', '.ps1', '.yaml', '.yml', '.toml', '.env'
  ];
  
  static const List<String> spreadsheetExtensions = [
    '.xls', '.xlsx', '.csv', '.ods', '.numbers'
  ];
  
  static const List<String> presentationExtensions = [
    '.ppt', '.pptx', '.key', '.odp'
  ];

  /// Sprawdza czy plik jest obrazem
  static bool isImage(String filename) {
    final extension = _getExtension(filename).toLowerCase();
    return imageExtensions.contains(extension);
  }

  /// Sprawdza czy plik jest wideo
  static bool isVideo(String filename) {
    final extension = _getExtension(filename).toLowerCase();
    return videoExtensions.contains(extension);
  }

  /// Sprawdza czy plik jest audio
  static bool isAudio(String filename) {
    final extension = _getExtension(filename).toLowerCase();
    return audioExtensions.contains(extension);
  }

  /// Sprawdza czy plik jest dokumentem
  static bool isDocument(String filename) {
    final extension = _getExtension(filename).toLowerCase();
    return documentExtensions.contains(extension);
  }

  /// Sprawdza czy plik jest plikiem tekstowym
  static bool isTextFile(String filename) {
    final extension = _getExtension(filename).toLowerCase();
    return textExtensions.contains(extension);
  }

  /// Sprawdza czy plik jest arkuszem kalkulacyjnym
  static bool isSpreadsheet(String filename) {
    final extension = _getExtension(filename).toLowerCase();
    return spreadsheetExtensions.contains(extension);
  }

  /// Sprawdza czy plik jest PDF
  static bool isPdf(String filename) {
    final extension = _getExtension(filename).toLowerCase();
    return extension == '.pdf';
  }

  /// Sprawdza czy plik jest prezentacją
  static bool isPresentation(String filename) {
    final extension = _getExtension(filename).toLowerCase();
    return presentationExtensions.contains(extension);
  }

  /// Sprawdza czy plik jest archiwum
  static bool isArchive(String filename) {
    final extension = _getExtension(filename).toLowerCase();
    return ['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2'].contains(extension);
  }

  /// Pobiera rozszerzenie pliku
  static String _getExtension(String filename) {
    final lastDotIndex = filename.lastIndexOf('.');
    if (lastDotIndex == -1) return '';
    return filename.substring(lastDotIndex);
  }

  /// Formatuje rozmiar pliku w czytelny sposób
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Pobiera ikonę dla typu pliku
  static String getFileIcon(String filename) {
    if (isImage(filename)) return '🖼️';
    if (isVideo(filename)) return '🎥';
    if (isAudio(filename)) return '🎵';
    if (isTextFile(filename)) return '📝';
    if (isPdf(filename)) return '📕';
    if (isDocument(filename)) return '📄';
    if (isSpreadsheet(filename)) return '📊';
    if (isPresentation(filename)) return '📽️';
    if (isArchive(filename)) return '📦';
    return '📁';
  }

  /// Pobiera kolor dla typu pliku
  static int getFileColor(String filename) {
    if (isImage(filename)) return 0xFF4CAF50; // Zielony
    if (isVideo(filename)) return 0xFF2196F3; // Niebieski
    if (isAudio(filename)) return 0xFF9C27B0; // Fioletowy
    if (isTextFile(filename)) return 0xFF00BCD4; // Cyjan
    if (isPdf(filename)) return 0xFFF44336; // Czerwony (PDF)
    if (isDocument(filename)) return 0xFFFF9800; // Pomarańczowy
    if (isSpreadsheet(filename)) return 0xFF4CAF50; // Zielony
    if (isPresentation(filename)) return 0xFFE91E63; // Różowy
    if (isArchive(filename)) return 0xFF795548; // Brązowy
    return 0xFF607D8B; // Szary
  }
} 