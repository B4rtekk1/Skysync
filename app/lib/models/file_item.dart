class FileItem {
  final int? id;
  final String name;
  final int size;
  final String mimeType;
  final DateTime lastModified;
  final bool isFavorite;
  final int? fileCount;
  final int? folderCount;
  final int? totalSize;

  FileItem({
    this.id,
    required this.name,
    required this.size,
    required this.mimeType,
    required this.lastModified,
    this.isFavorite = false,
    this.fileCount,
    this.folderCount,
    this.totalSize,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      id: json['id'] as int?,
      name: json['name'] as String,
      size: json['size'] as int,
      mimeType: json['mime_type'] as String,
      lastModified: DateTime.parse(json['last_modified'] as String),
      isFavorite: json['is_favorite'] as bool? ?? false,
      fileCount: json['file_count'] as int?,
      folderCount: json['folder_count'] as int?,
      totalSize: json['total_size'] as int?,
    );
  }

  bool get isFolder => mimeType == 'folder' || mimeType == 'directory';

  String get formattedSize {
    if (isFolder && totalSize != null) {
      return _formatBytes(totalSize!);
    }
    return _formatBytes(size);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get folderInfo {
    if (!isFolder) return '';
    final parts = <String>[];
    if (fileCount != null && fileCount! > 0) {
      parts.add('$fileCount ${fileCount == 1 ? 'file' : 'files'}');
    }
    if (folderCount != null && folderCount! > 0) {
      parts.add('$folderCount ${folderCount == 1 ? 'folder' : 'folders'}');
    }
    return parts.isEmpty ? 'Empty' : parts.join(', ');
  }
}
