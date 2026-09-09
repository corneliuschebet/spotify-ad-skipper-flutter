import 'dart:async';

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

  String spotifyStatus = 'Waiting';
  String lastEvent = 'System ready.';
  String lastTrack = '';

  int adsDetected = 0;

  final List<String> activityLog = [];

  StreamSubscription<Map<String, dynamic>>? _spotifyEventSubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadPlatformInfo();
    _loadNotificationListenerStatus();
    _listenToSpotifyEvents();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _spotifyEventSubscription?.cancel();

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

  void _listenToSpotifyEvents() {
    _spotifyEventSubscription = AndroidBridge.spotifyEvents.listen(
      _handleSpotifyEvent,
      onError: (error) {
        debugPrint('Spotify event stream error: $error');

        if (!mounted) return;

        setState(() {
          lastEvent = 'Spotify event stream error';
        });
      },
    );
  }

  void _handleSpotifyEvent(Map<String, dynamic> event) {
    if (!mounted) return;

    final type = event['type']?.toString() ?? 'unknown';

    switch (type) {
      case 'advertisement':
        final title = event['title']?.toString() ?? '';
        final text = event['text']?.toString() ?? '';

        setState(() {
          spotifyStatus = 'Advertisement detected';
          adsDetected++;

          lastEvent = '🚨 Spotify advertisement detected';

          _addActivity(
            '🚨 Advertisement detected'
            '${text.isNotEmpty ? ' — $text' : ''}',
          );
        });

        debugPrint(
          'Advertisement event received: '
          'title=$title, text=$text',
        );
        break;

      case 'music':
        final title = event['title']?.toString() ?? '';
        final text = event['text']?.toString() ?? '';

        setState(() {
          spotifyStatus = 'Playing music';
          lastTrack = title;

          lastEvent = '🎵 Music detected';

          _addActivity(
            '🎵 $title'
            '${text.isNotEmpty ? ' — $text' : ''}',
          );
        });

        debugPrint(
          'Music event received: '
          'title=$title, text=$text',
        );
        break;

      case 'ignored':
        final reason = event['reason']?.toString();

        setState(() {
          if (reason == 'empty_notification') {
            _addActivity('⚪ Empty Spotify notification ignored');
          } else {
            _addActivity('⚪ Spotify notification ignored');
          }
        });

        break;

      case 'notification_removed':
        setState(() {
          _addActivity('🔕 Spotify notification removed');
        });

        break;

      default:
        setState(() {
          _addActivity('ℹ️ Unknown Spotify event: $type');
        });
    }
  }

  void _addActivity(String message) {
    activityLog.insert(0, message);

    if (activityLog.length > 8) {
      activityLog.removeLast();
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

            _statusRow(Icons.music_note, 'Spotify', spotifyStatus),

            _statusRow(
              Icons.notifications,
              'Notifications',
              notificationStatus,
            ),

            _statusRow(Icons.settings, 'Android Service', 'Detection active'),

            if (lastTrack.isNotEmpty) ...[
              const SizedBox(height: 8),
              _statusRow(Icons.album, 'Current Track', lastTrack),
            ],
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

          Flexible(
            child: Text(
              status,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
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
        openingSettings
            ? 'Opening Settings...'
            : notificationListenerEnabled
            ? 'Notification Access Enabled'
            : 'Enable Skipper',
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
        Expanded(
          child: _statCard(
            'Ads Detected',
            adsDetected.toString(),
            Icons.warning_amber,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _statCard(
            'Events',
            activityLog.length.toString(),
            Icons.notifications_active,
          ),
        ),
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

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
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
              child: activityLog.isEmpty
                  ? const Text(
                      'System ready.\n'
                      'Waiting for Spotify notifications...',
                      style: TextStyle(color: Colors.grey, height: 1.5),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lastEvent,
                          style: const TextStyle(
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 16),

                        for (final activity in activityLog)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              activity,
                              style: const TextStyle(height: 1.4),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
