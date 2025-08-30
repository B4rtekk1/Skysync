# Storage Features in Settings Page

## Overview

The settings page now includes comprehensive storage information that shows real-time data about device storage and application usage.

## New Features

### 1. Storage Information Tile

- **Location**: Settings → Data & Sync section
- **Shows**:
  - Total device storage (GB)
  - Used storage (GB)
  - Available storage (GB)
  - Usage percentage
  - Application size (MB)
- **Visual Elements**:
  - Progress bar showing storage usage
  - Color-coded progress bar (green < 60%, orange 60-80%, red > 80%)
  - Refresh button to update information

### 2. Enhanced Cache Tile

- **Location**: Settings → Data & Sync section
- **Shows**:
  - Images cache size (MB)
  - Temporary files size (MB)
  - Total cache size (MB)
- **Actions**:
  - Refresh button to update cache info
  - Clear button to delete all cache

### 3. App Size Tile

- **Location**: Settings → Data & Sync section
- **Shows**:
  - Total application size (MB)
- **Actions**:
  - Refresh button to update app size info

## Technical Implementation

### StorageService Class

- **File**: `lib/utils/storage_service.dart`
- **Features**:
  - Cross-platform storage detection (Android, iOS, Windows, macOS, Linux)
  - Real-time directory size calculation
  - Device storage information retrieval
  - Cache management utilities

### Platform Support

- **Android**: Uses `df` command to get storage info
- **iOS**: Uses `df` command to get storage info  
- **Windows**: Uses `wmic` command to get disk information
- **macOS**: Uses `df` command to get storage info
- **Linux**: Uses `df` command to get storage info

### Data Sources

- **Application Documents Directory**: Main app data
- **Temporary Directory**: Cache and temp files
- **Application Support Directory**: App support files
- **Device Storage**: Total device capacity and usage

## Usage

### For Users

1. Navigate to Settings → Data & Sync
2. View storage information in the Storage Info tile
3. Use refresh buttons to get latest information
4. Monitor storage usage with the progress bar
5. Clear cache when needed to free up space

### For Developers

1. Import `StorageService` in your Dart files
2. Use `StorageService().getDeviceStorageInfo()` to get storage data
3. Call `StorageService().clearAppCache()` to clear application cache
4. Handle platform-specific storage queries as needed

## Localization

All storage-related text is localized and supports:

- Polish (pl)
- English (en)

## Error Handling

- Graceful fallback to default values if storage detection fails
- Platform-specific error handling
- User-friendly error messages
- Automatic retry mechanisms

## Performance Considerations

- Storage information is calculated on-demand
- Cache statistics are updated when cache operations occur
- Directory scanning is optimized for large file structures
- Background processing for storage calculations

## Future Enhancements

- Real-time storage monitoring
- Storage usage trends and analytics
- Automatic cache cleanup recommendations
- Storage optimization suggestions
- Cloud storage integration
