import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../providers/jobs_provider.dart';
import '../services/attachment_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _storageBytes = 0;
  bool _isLoadingStorage = true;

  @override
  void initState() {
    super.initState();
    _refreshStorageUsage();
  }

  Future<void> _refreshStorageUsage() async {
    setState(() => _isLoadingStorage = true);
    final bytes = await AttachmentService.instance.getTotalStorageBytes();
    if (mounted) {
      setState(() {
        _storageBytes = bytes;
        _isLoadingStorage = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _confirmClearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Reset All App Data?'),
          ],
        ),
        content: const Text(
          'This will permanently delete:\n• All service jobs and history\n• All inspection checklists\n• All captured customer signatures\n• All photos and local files\n• All saved templates\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Erase Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<JobsProvider>().clearAllAppData();
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final jobsProvider = context.watch<JobsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Theme Mode Section
            _buildSectionHeader(context, 'Appearance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Color Theme',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose between daylight high-contrast, dark slate field mode, or match your Android system settings.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.brightness_auto_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_rounded, size: 16),
                        ),
                      ],
                      selected: {themeProvider.themeMode},
                      onSelectionChanged: (selected) {
                        themeProvider.setThemeMode(selected.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Local Storage Section
            _buildSectionHeader(context, 'Storage & Privacy'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Attachment & Evidence Storage',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (_isLoadingStorage)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Text(
                            _formatBytes(_storageBytes),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All job records, photos, signatures, and notes are stored purely offline on this device in SQLite and private app storage. No data is sent to external cloud servers.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _refreshStorageUsage,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Recalculate Storage'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Demo Data Section
            _buildSectionHeader(context, 'Sample Data'),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.science_outlined,
                  color: Color(0xFF2563EB),
                ),
                title: const Text('Load Demo Workspace'),
                subtitle: const Text(
                  'Populates sample jobs, customers, and checklists for interviews.',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    await jobsProvider.loadDemoWorkspace();
                    _refreshStorageUsage();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Demo workspace loaded successfully.'),
                        ),
                      );
                    }
                  },
                  child: const Text('Load Demo'),
                ),
              ),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFFEFF6FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFBFDBFE), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF1D4ED8),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Browser Local Storage',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Web data is stored locally in this browser using IndexedDB & WebAssembly SQLite. '
                              'It does not automatically synchronize to your Android device. '
                              'Clearing browser site data or using private/incognito browsing may erase this local workspace.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF1E40AF),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Danger Zone
            _buildSectionHeader(context, 'Reset Workspace'),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFFCA5A5), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clear All App Data',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Permanently removes all database tables, attachments, and signatures. Returns app to first-time setup.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _confirmClearAllData,
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text('Clear All Local Data'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // About FieldFlow
            Center(
              child: Column(
                children: [
                  const Text(
                    'FieldFlow v1.0.0',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Offline Field Service Management • Flutter Portfolio Project',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
