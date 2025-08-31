import 'package:flutter/material.dart';
import '../utils/custom_widgets.dart';
import '../utils/token_service.dart';
import '../utils/app_settings.dart';
import '../utils/cache_service.dart';
import '../utils/storage_service.dart';
import 'package:easy_localization/easy_localization.dart';

class SettingsPage extends StatefulWidget {
  final String? deleteAccountEmail;
  const SettingsPage({super.key, this.deleteAccountEmail});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with TickerProviderStateMixin {
  // User data
  String _username = 'loading';
  String _email = 'loading@example.com';

  // Appearance
  String _fontSize = 'medium';
  String _defaultView = 'list';
  String _defaultSort = 'name';

  // Language
  String _language = 'pl';
  bool _autoDetectLang = false;

  // Account & Security
  bool _2faEnabled = false;

  // Data & Sync
  bool _autoSync = true;
  bool _wifiOnly = true;
  double _cacheSize = 0.0; // MB
  Map<String, dynamic> _cacheStats = {};
  Map<String, dynamic> _storageInfo = {};

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAppSettings();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final username = await TokenService.getUsername();
    final email = await TokenService.getEmail();
    setState(() {
      _username = username ?? 'unknown';
      _email = email ?? 'unknown';
    });
  }

  Future<void> _loadAppSettings() async {
    try {
      await AppSettings().initialize();
      await _loadCacheStats();
      await _loadStorageInfo();
      setState(() {
        _fontSize = AppSettings().fontSize;
        _defaultView = AppSettings().defaultView;
        _defaultSort = AppSettings().defaultSort;
      });
    } catch (e) {
      print('Błąd podczas ładowania ustawień aplikacji: $e');
      // Ustaw domyślne wartości w przypadku błędu
      setState(() {
        _fontSize = 'medium';
        _defaultView = 'list';
        _defaultSort = 'name';
      });
    }
  }

  Future<void> _loadCacheStats() async {
    final stats = CacheService().getCacheStats();
    setState(() {
      _cacheStats = stats;
      _cacheSize =
          double.tryParse(stats['images_cache_size_mb'] ?? '0.0') ?? 0.0;
    });
  }

  Future<void> _loadStorageInfo() async {
    try {
      final storageInfo = await StorageService().getDeviceStorageInfo();
      setState(() {
        _storageInfo = storageInfo;
      });
    } catch (e) {
      print('Błąd podczas ładowania informacji o storage: $e');
      setState(() {
        _storageInfo = {};
      });
    }
  }

  /// Zwraca bezpieczną wartość dla LinearProgressIndicator (0.0 - 1.0)
  double _getValidProgressValue(String percentageStr) {
    try {
      // Sprawdź czy string nie jest pusty lub null
      if (percentageStr.isEmpty || percentageStr == 'null') {
        return 0.0;
      }
      
      final percentage = double.tryParse(percentageStr);
      if (percentage == null || percentage.isNaN || percentage.isInfinite) {
        return 0.0;
      }
      
      // Upewnij się, że wartość jest między 0.0 a 1.0
      final normalizedValue = (percentage / 100).clamp(0.0, 1.0);
      return normalizedValue;
    } catch (e) {
      print('Błąd podczas parsowania procentu: $e');
      return 0.0;
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('settings.clear_cache_title'.tr()),
          content: Text('settings.clear_cache_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('settings.cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('settings.clear'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await CacheService().clearAllCache();
      await _loadCacheStats();
      await _loadStorageInfo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings.cache_cleared'.tr()),
            backgroundColor: const Color(0xFF667eea),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CustomDrawer(
        username: _username,
        email: _email,
        currentRoute: '/settings',
        onSignOut: () {
          Navigator.pushReplacementNamed(context, '/login');
        },
      ),
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
        title: Text(
          'settings'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      backgroundColor: const Color(0xFFf8fafc),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildUserProfileCard(),
              const SizedBox(height: 24),
              _buildSettingsSection(
                'appearance'.tr(),
                Icons.palette,
                const Color(0xFF667eea),
                [
                  _buildDropdownTile(
                    'font_size'.tr(),
                    _fontSize,
                    [
                      {'value': 'small', 'label': 'small'.tr()},
                      {'value': 'medium', 'label': 'medium'.tr()},
                      {'value': 'large', 'label': 'large'.tr()},
                    ],
                    (val) async {
                      if (val != null) {
                        await AppSettings().setFontSize(val);
                        setState(() => _fontSize = val);
                        _showRestartDialog();
                      }
                    },
                    Icons.format_size,
                  ),
                  _buildDropdownTile(
                    'default_view'.tr(),
                    _defaultView,
                    [
                      {'value': 'list', 'label': 'list'.tr()},
                      {'value': 'grid', 'label': 'grid'.tr()},
                    ],
                    (val) async {
                      if (val != null) {
                        await AppSettings().setDefaultView(val);
                        setState(() => _defaultView = val);
                      }
                    },
                    Icons.view_list,
                  ),
                  _buildDropdownTile(
                    'default_sort'.tr(),
                    _defaultSort,
                    [
                      {'value': 'name', 'label': 'name'.tr()},
                      {'value': 'date', 'label': 'date'.tr()},
                      {'value': 'size', 'label': 'size'.tr()},
                      {'value': 'type', 'label': 'type'.tr()},
                    ],
                    (val) async {
                      if (val != null) {
                        await AppSettings().setDefaultSort(val);
                        setState(() => _defaultSort = val);
                      }
                    },
                    Icons.sort,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSettingsSection(
                'language'.tr(),
                Icons.language,
                const Color(0xFF764ba2),
                [
                  _buildSwitchTile(
                    'auto_detect_language'.tr(),
                    _autoDetectLang,
                    (val) => setState(() => _autoDetectLang = val),
                    Icons.language,
                    Icons.language,
                  ),
                  _buildLanguageDropdown(),
                ],
              ),
              const SizedBox(height: 24),

              const SizedBox(height: 24),
              _buildSettingsSection(
                'account_security'.tr(),
                Icons.security,
                const Color(0xFF4facfe),
                [
                  _buildActionTile('edit_profile'.tr(), Icons.person, () {}),
                  _buildActionTile('change_password'.tr(), Icons.lock, () {
                    TokenService.logout().then((_) {
                      Navigator.pushReplacementNamed(context, '/login');
                      Navigator.pushNamed(
                        context,
                        '/forgot-password',
                        arguments: _email,
                      );
                    });
                  }),
                  _buildActionTile(
                    'log_out_other_devices'.tr(),
                    Icons.logout,
                    () {},
                  ),
                  _buildActionTile(
                    'delete_account'.tr(),
                    Icons.delete_forever,
                    () {
                      TokenService.logout().then((_) {
                        Navigator.pushReplacementNamed(context, '/login');
                        Navigator.pushReplacementNamed(
                          context,
                          '/delete_account',
                        );
                      });
                    },
                    isDestructive: true,
                  ),
                  _buildSwitchTile(
                    'two_factor_auth'.tr(),
                    _2faEnabled,
                    (val) => setState(() => _2faEnabled = val),
                    Icons.verified_user,
                    Icons.verified_user,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSettingsSection(
                'data_sync'.tr(),
                Icons.sync,
                const Color(0xFF43e97b),
                [
                  _buildSwitchTile(
                    'auto_sync'.tr(),
                    _autoSync,
                    (val) => setState(() => _autoSync = val),
                    Icons.sync,
                    Icons.sync_disabled,
                  ),
                  _buildSwitchTile(
                    'sync_only_wifi'.tr(),
                    _wifiOnly,
                    (val) => setState(() => _wifiOnly = val),
                    Icons.wifi,
                    Icons.wifi_off,
                  ),
                  _buildCacheTile(),
                  _buildStorageTile(),
                  _buildAppSizeTile(),
                ],
              ),

              const SizedBox(height: 24),
              _buildSettingsSection(
                'info'.tr(),
                Icons.info,
                const Color(0xFFa8edea),
                [
                  _buildActionTile('about'.tr(), Icons.info_outline, () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'ServApp',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2024 Bartosz Kasyna',
                    );
                  }),
                  _buildActionTile(
                    'privacy_policy'.tr(),
                    Icons.privacy_tip,
                    () {},
                  ),
                  _buildActionTile('terms_of_service'.tr(), Icons.rule, () {}),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfileCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _username,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit,
              color: Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
    IconData iconOn,
    IconData iconOff, {
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color:
            enabled
                ? Theme.of(context).colorScheme.surfaceVariant
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color:
                enabled
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: const Color(0xFF667eea),
        secondary: Icon(
          value ? iconOn : iconOff,
          color: enabled ? const Color(0xFF667eea) : Colors.grey,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCheckboxTile(
    String title,
    bool value,
    ValueChanged<bool?> onChanged,
    bool enabled,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color:
            enabled
                ? Theme.of(context).colorScheme.surfaceVariant
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CheckboxListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color:
                enabled
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: const Color(0xFF667eea),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String value,
    List<Map<String, String>> items,
    ValueChanged<String?> onChanged,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF667eea)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: DropdownButton<String>(
          value: value,
          items:
              items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item['value'],
                      child: Text(item['label']!),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
          underline: Container(),
          icon: const Icon(Icons.arrow_drop_down),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DropdownButtonFormField<String>(
          value: _language,
          decoration: InputDecoration(
            labelText: 'select_language'.tr(),
            border: InputBorder.none,
            icon: const Icon(Icons.language, color: Color(0xFF667eea)),
          ),
          items: [
            DropdownMenuItem(value: 'pl', child: Text('polish'.tr())),
            DropdownMenuItem(value: 'en', child: Text('english'.tr())),
          ],
          onChanged: (val) async {
            setState(() => _language = val ?? 'pl');
            if (val != null) {
              await context.setLocale(Locale(val));
            }
          },
        ),
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? Colors.red : const Color(0xFF667eea),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDestructive ? Colors.red : Colors.black87,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCacheTile() {
    final imagesCacheSize = _storageInfo['cache_size_mb']?.toString() ?? '0.0';
    final tempSize = _storageInfo['temp_size_mb']?.toString() ?? '0.0';
    final totalCacheSize = (double.tryParse(imagesCacheSize) ?? 0.0) + (double.tryParse(tempSize) ?? 0.0);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const Icon(Icons.cached, color: Color(0xFF667eea)),
        title: Text(
          'cache_size'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'images_cache'.tr()}: ${imagesCacheSize} MB',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '${'temp_cache'.tr()}: ${tempSize} MB',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '${'total_cache'.tr()}: ${totalCacheSize.toStringAsFixed(1)} MB',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF667eea)),
              onPressed: () async {
                await _loadCacheStats();
                await _loadStorageInfo();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('cache_refreshed'.tr()),
                    backgroundColor: const Color(0xFF667eea),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _clearCache,
            ),
          ],
        ),
        isThreeLine: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildStorageTile() {
    final totalGB = _storageInfo['device_total_gb']?.toString() ?? '0.0';
    final usedGB = _storageInfo['device_used_gb']?.toString() ?? '0.0';
    final availableGB = _storageInfo['device_available_gb']?.toString() ?? '0.0';
    final usedPercentage = _storageInfo['device_used_percentage']?.toString() ?? '0.0';
    final appSizeMB = _storageInfo['total_app_size_mb']?.toString() ?? '0.0';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const Icon(Icons.storage, color: Color(0xFF667eea)),
        title: Text(
          'storage_info'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'device_storage'.tr()}: $totalGB GB total, $usedGB GB used ($usedPercentage%) $availableGB GB free',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '${'app_storage'.tr()}: $appSizeMB MB',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _getValidProgressValue(usedPercentage),
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getValidProgressValue(usedPercentage) > 0.8
                    ? Colors.red
                    : _getValidProgressValue(usedPercentage) > 0.6
                        ? Colors.orange
                        : const Color(0xFF667eea),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF667eea)),
          onPressed: () async {
            await _loadStorageInfo();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('storage_refreshed'.tr()),
                backgroundColor: const Color(0xFF667eea),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
        isThreeLine: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildAppSizeTile() {
    final appSizeMB = _storageInfo['app_size_mb']?.toString() ?? '0.0';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const Icon(Icons.apps, color: Color(0xFF667eea)),
        title: Text(
          'app_size'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${appSizeMB} MB',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF667eea)),
          onPressed: () async {
            await _loadStorageInfo();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('app_size_refreshed'.tr()),
                backgroundColor: const Color(0xFF667eea),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('restart_required'.tr()),
          content: Text('restart_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('common.ok'.tr()),
            ),
          ],
        );
      },
    );
  }
}
