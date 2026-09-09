import 'package:flutter/material.dart';

import 'services/android_bridge.dart';

void main() {
  runApp(const SpotifyAdSkipperApp());
}

class SpotifyAdSkipperApp extends StatelessWidget {
  const SpotifyAdSkipperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spotify Ad Skipper',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1DB954),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? platformInfo;

  bool notificationListenerEnabled = false;
  bool loadingNotificationStatus = true;
  bool openingSettings = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadPlatformInfo();
    _loadNotificationListenerStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotificationListenerStatus();
    }
  }

  Future<void> _loadPlatformInfo() async {
    try {
      final info = await AndroidBridge.getPlatformInfo();

      if (!mounted) return;

      setState(() {
        platformInfo = info;
      });
    } catch (error) {
      debugPrint('Failed to load Android platform information: $error');
    }
  }

  Future<void> _loadNotificationListenerStatus() async {
    try {
      final enabled = await AndroidBridge.isNotificationListenerEnabled();

      if (!mounted) return;

      setState(() {
        notificationListenerEnabled = enabled;
        loadingNotificationStatus = false;
      });
    } catch (error) {
      debugPrint('Failed to load notification listener status: $error');

      if (!mounted) return;

      setState(() {
        notificationListenerEnabled = false;
        loadingNotificationStatus = false;
      });
    }
  }

  Future<void> _enableSkipper() async {
    if (openingSettings) return;

    setState(() {
      openingSettings = true;
    });

    try {
      await AndroidBridge.openNotificationListenerSettings();
    } catch (error) {
      debugPrint('Failed to open notification listener settings: $error');
    }

    if (!mounted) return;

    setState(() {
      openingSettings = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Spotify Ad Skipper',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF121212),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 20),
            _buildPlatformCard(),
            const SizedBox(height: 20),
            _buildControlButton(),
            const SizedBox(height: 24),
            _buildStatistics(),
            const SizedBox(height: 24),
            _buildActivityLog(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final notificationStatus = loadingNotificationStatus
        ? 'Checking...'
        : notificationListenerEnabled
        ? 'Connected'
        : 'Not connected';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.circle, color: Color(0xFF1DB954), size: 14),
                SizedBox(width: 10),
                Text(
                  'Service Status',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _statusRow(Icons.music_note, 'Spotify', 'Waiting'),
            _statusRow(
              Icons.notifications,
              'Notifications',
              notificationStatus,
            ),
            _statusRow(Icons.settings, 'Android Service', 'Not configured'),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformCard() {
    final info = platformInfo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.phone_android),
                SizedBox(width: 10),
                Text(
                  'Android Device',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _statusRow(
              Icons.business,
              'Manufacturer',
              info?['manufacturer']?.toString() ?? 'Loading...',
            ),
            _statusRow(
              Icons.smartphone,
              'Model',
              info?['model']?.toString() ?? 'Loading...',
            ),
            _statusRow(
              Icons.android,
              'Android',
              info?['androidVersion']?.toString() ?? 'Loading...',
            ),
            _statusRow(
              Icons.code,
              'SDK',
              info?['sdkInt']?.toString() ?? 'Loading...',
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(IconData icon, String title, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          Text(status, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildControlButton() {
    return FilledButton.icon(
      onPressed: openingSettings ? null : _enableSkipper,
      icon: openingSettings
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.power_settings_new),
      label: Text(
        openingSettings ? 'Opening Settings...' : 'Enable Skipper',
        style: const TextStyle(fontSize: 16),
      ),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildStatistics() {
    return Row(
      children: [
        Expanded(child: _statCard('Ads Skipped', '0', Icons.skip_next)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Uptime', '00:00', Icons.timer)),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 30),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityLog() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history),
                SizedBox(width: 10),
                Text(
                  'Activity Log',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'System ready.\n'
                'Waiting for Android service configuration...',
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
