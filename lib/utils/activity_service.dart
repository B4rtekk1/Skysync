import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

enum ActivityType {
  fileUpload,
  fileDownload,
  fileDelete,
  fileRename,
  fileShare,
  fileUnshare,
  folderCreate,
  fileMove,
  fileFavorite,
  fileUnfavorite,
}

class ActivityItem {
  final String id;
  final ActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'title': title,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: json['id'],
      type: ActivityType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ActivityType.fileUpload,
      ),
      title: json['title'],
      description: json['description'],
      timestamp: DateTime.parse(json['timestamp']),
      metadata: json['metadata'],
    );
  }
}

class ActivityService {
  static const String _activityKey = 'user_activity';
  static const int _maxActivities = 20; // Maksymalna liczba zapisanych aktywności

  // Dodaj nową aktywność
  static Future<void> addActivity(ActivityItem activity) async {
    try {
      print('DEBUG: Adding activity: ${activity.title}');
      final prefs = await SharedPreferences.getInstance();
      final activitiesJson = prefs.getStringList(_activityKey) ?? [];
      
      print('DEBUG: Current activities count: ${activitiesJson.length}');
      
      // Konwertuj aktywności na obiekty
      List<ActivityItem> activities = activitiesJson
          .map((json) => ActivityItem.fromJson(jsonDecode(json)))
          .toList();
      
      // Dodaj nową aktywność na początku listy
      activities.insert(0, activity);
      
      // Ogranicz liczbę aktywności
      if (activities.length > _maxActivities) {
        activities = activities.take(_maxActivities).toList();
      }
      
      // Zapisz z powrotem
      final newActivitiesJson = activities
          .map((activity) => jsonEncode(activity.toJson()))
          .toList();
      
      await prefs.setStringList(_activityKey, newActivitiesJson);
      print('DEBUG: Activity saved successfully. Total activities: ${activities.length}');
    } catch (e) {
      print('Error saving activity: $e');
    }
  }

  // Pobierz wszystkie aktywności
  static Future<List<ActivityItem>> getActivities() async {
    try {
      print('DEBUG: Getting activities...');
      final prefs = await SharedPreferences.getInstance();
      final activitiesJson = prefs.getStringList(_activityKey) ?? [];
      
      print('DEBUG: Found ${activitiesJson.length} activities in storage');
      
      final activities = activitiesJson
          .map((json) => ActivityItem.fromJson(jsonDecode(json)))
          .toList();
      
      print('DEBUG: Parsed ${activities.length} activities');
      return activities;
    } catch (e) {
      print('Error loading activities: $e');
      return [];
    }
  }

  // Wyczyść wszystkie aktywności
  static Future<void> clearActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activityKey);
    } catch (e) {
      print('Error clearing activities: $e');
    }
  }

  // Usuń aktywność po ID
  static Future<void> removeActivity(String activityId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activitiesJson = prefs.getStringList(_activityKey) ?? [];
      
      final activities = activitiesJson
          .map((json) => ActivityItem.fromJson(jsonDecode(json)))
          .toList();
      
      // Usuń aktywność o podanym ID
      activities.removeWhere((activity) => activity.id == activityId);
      
      // Zapisz z powrotem
      final newActivitiesJson = activities
          .map((activity) => jsonEncode(activity.toJson()))
          .toList();
      
      await prefs.setStringList(_activityKey, newActivitiesJson);
      print('DEBUG: Activity $activityId removed successfully. Remaining activities: ${activities.length}');
    } catch (e) {
      print('Error removing activity: $e');
    }
  }

  // Helper metody do tworzenia aktywności
  static ActivityItem createFileUploadActivity(String filename) {
    return ActivityItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ActivityType.fileUpload,
      title: 'activity.file_uploaded'.tr(),
      description: 'activity.uploaded'.tr(namedArgs: {'filename': filename}),
      timestamp: DateTime.now(),
      metadata: {'filename': filename},
    );
  }

  static ActivityItem createFileDownloadActivity(String filename) {
    return ActivityItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ActivityType.fileDownload,
      title: 'activity.file_downloaded'.tr(),
      description: 'activity.downloaded'.tr(namedArgs: {'filename': filename}),
      timestamp: DateTime.now(),
      metadata: {'filename': filename},
    );
  }

  static ActivityItem createFileDeleteActivity(String filename) {
    return ActivityItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ActivityType.fileDelete,
      title: 'activity.file_deleted'.tr(),
      description: 'activity.deleted'.tr(namedArgs: {'filename': filename}),
      timestamp: DateTime.now(),
      metadata: {'filename': filename},
    );
  }

  static ActivityItem createFileRenameActivity(String oldName, String newName) {
    return ActivityItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ActivityType.fileRename,
      title: 'activity.file_renamed'.tr(),
      description: 'activity.renamed'.tr(namedArgs: {'oldname': oldName, 'newname': newName}),
      timestamp: DateTime.now(),
      metadata: {'oldName': oldName, 'newName': newName},
    );
  }

  static ActivityItem createFileShareActivity(String filename, String user) {
    return ActivityItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ActivityType.fileShare,
      title: 'activity.file_shared'.tr(),
      description: 'activity.shared'.tr(namedArgs: {'filename': filename, 'user': user}),
      timestamp: DateTime.now(),
      metadata: {'filename': filename, 'user': user},
    );
  }

  static ActivityItem createFileUnshareActivity(String filename, String user) {
    return ActivityItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ActivityType.fileUnshare,
      title: 'activity.file_unshared'.tr(),
      description: 'activity.unshared'.tr(namedArgs: {'filename': filename, 'user': user}),
      timestamp: DateTime.now(),
      metadata: {'filename': filename, 'user': user},
    );
  }

  static ActivityItem createFolderCreateActivity(String folderName) {
    return ActivityItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ActivityType.folderCreate,
      title: 'activity.folder_created'.tr(),
      description: 'activity.folder_created_desc'.tr(namedArgs: {'foldername': folderName}),
      timestamp: DateTime.now(),
      metadata: {'folderName': folderName},
    );
  }

  static ActivityItem createFileMoveActivity(String filename, String destination) {
    return ActivityItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ActivityType.fileMove,
      title: 'activity.file_moved'.tr(),
      description: 'activity.moved'.tr(namedArgs: {'filename': filename, 'destination': destination}),
      timestamp: DateTime.now(),
      metadata: {'filename': filename, 'destination': destination},
    );
  }

  static ActivityItem createFileFavoriteActivity(String filename) {
    return ActivityItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ActivityType.fileFavorite,
      title: 'activity.file_favorited'.tr(),
      description: 'activity.favorited'.tr(namedArgs: {'filename': filename}),
      timestamp: DateTime.now(),
      metadata: {'filename': filename},
    );
  }

  static ActivityItem createFileUnfavoriteActivity(String filename) {
    return ActivityItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ActivityType.fileUnfavorite,
      title: 'activity.file_unfavorited'.tr(),
      description: 'activity.unfavorited'.tr(namedArgs: {'filename': filename}),
      timestamp: DateTime.now(),
      metadata: {'filename': filename},
    );
  }

  static ActivityItem createFilePreviewActivity(String filename) {
    return ActivityItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ActivityType.fileDownload, // Using download type for preview
      title: 'activity.file_previewed'.tr(),
      description: 'activity.previewed'.tr(namedArgs: {'filename': filename}),
      timestamp: DateTime.now(),
      metadata: {'filename': filename},
    );
  }
} 