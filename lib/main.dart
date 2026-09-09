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
        fontFamily: 'Roboto',
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
  static const Color spotifyGreen = Color(0xFF1DB954);
  static const Color darkBackground = Color(0xFF121212);
  static const Color cardBackground = Color(0xFF181818);

  Map<String, dynamic>? platformInfo;

  bool notificationListenerEnabled = false;
  bool loadingNotificationStatus = true;
  bool openingSettings = false;

  bool spotifyConnected = false;
  bool isPaused = false;

  String spotifyStatus = 'Waiting for Spotify';
  String lastEvent = 'System ready.';
  String lastTrack = '';
  String lastArtist = '';

  int adsDetected = 0;
  int eventsReceived = 0;

  final List<String> activityLog = [];

  StreamSubscription<Map<String, dynamic>>? _spotifyEventSubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadPlatformInfo();
    _loadNotificationListenerStatus();
    _loadSpotifyStatus();
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
      _loadSpotifyStatus();
    }
  }

  Future<void> _loadPlatformInfo() async {
    try {
      final info = await AndroidBridge.getPlatformInfo();

      if (!mounted) {
        return;
      }

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

      if (!mounted) {
        return;
      }

      setState(() {
        notificationListenerEnabled = enabled;
        loadingNotificationStatus = false;
      });
    } catch (error) {
      debugPrint('Failed to load notification listener status: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        notificationListenerEnabled = false;
        loadingNotificationStatus = false;
      });
    }
  }

  Future<void> _loadSpotifyStatus() async {
    try {
      final running = await AndroidBridge.isSkipperRunning();

      if (!mounted) {
        return;
      }

      setState(() {
        spotifyConnected = running;
      });
    } catch (error) {
      debugPrint('Failed to load Spotify status: $error');
    }
  }

  void _listenToSpotifyEvents() {
    _spotifyEventSubscription = AndroidBridge.spotifyEvents.listen(
      _handleSpotifyEvent,
      onError: (error) {
        debugPrint('Spotify event stream error: $error');

        if (!mounted) {
          return;
        }

        setState(() {
          lastEvent = 'Spotify event stream error';
        });
      },
    );
  }

  void _handleSpotifyEvent(Map<String, dynamic> event) {
    if (!mounted) {
      return;
    }

    final type = event['type']?.toString() ?? 'unknown';

    eventsReceived++;

    switch (type) {
      case 'advertisement':
        _handleAdvertisement(event);
        break;

      case 'music':
        _handleMusic(event);
        break;

      case 'pause_sent':
        setState(() {
          isPaused = true;
          lastEvent = 'Playback paused';
        });

        _addActivity('⏸ Playback paused');
        break;

      case 'play_sent':
        setState(() {
          isPaused = false;
          lastEvent = 'Playback resumed';
        });

        _addActivity('▶ Playback resumed');
        break;

      case 'next_sent':
        setState(() {
          lastEvent = 'Skipped to next track';
        });

        _addActivity('⏭ Next track command sent');
        break;

      case 'next_unavailable':
        _addActivity('⚠ Next unavailable for current Spotify session');
        break;

      case 'pause_unavailable':
        _addActivity('⚠ Pause unavailable for current Spotify session');
        break;

      case 'play_unavailable':
        _addActivity('⚠ Play unavailable for current Spotify session');
        break;

      case 'ignored':
        final reason = event['reason']?.toString();

        if (reason == 'empty_notification') {
          _addActivity('⚪ Empty Spotify notification ignored');
        } else {
          _addActivity('⚪ Spotify notification ignored');
        }
        break;

      case 'notification_removed':
        _addActivity('🔕 Spotify notification removed');
        break;

      default:
        _addActivity('ℹ Spotify event: $type');
    }

    setState(() {});
  }

  void _handleAdvertisement(Map<String, dynamic> event) {
    final title = event['title']?.toString() ?? '';

    final text = event['text']?.toString() ?? '';

    setState(() {
      spotifyStatus = 'Advertisement detected';
      spotifyConnected = true;
      adsDetected++;
      lastEvent = 'Advertisement detected';
    });

    _addActivity(
      '🚨 Advertisement detected'
      '${text.isNotEmpty ? ' — $text' : ''}',
    );

    debugPrint(
      'Advertisement event received: '
      'title=$title, text=$text',
    );
  }

  void _handleMusic(Map<String, dynamic> event) {
    final title = event['title']?.toString() ?? '';

    final text = event['text']?.toString() ?? '';

    setState(() {
      spotifyStatus = 'Playing music';
      spotifyConnected = true;
      isPaused = false;
      lastTrack = title;
      lastArtist = text;
      lastEvent = 'Music detected';
    });

    _addActivity(
      '🎵 $title'
      '${text.isNotEmpty ? ' — $text' : ''}',
    );

    debugPrint(
      'Music event received: '
      'title=$title, text=$text',
    );
  }

  void _addActivity(String message) {
    activityLog.insert(0, message);

    if (activityLog.length > 10) {
      activityLog.removeLast();
    }
  }

  Future<void> _enableSkipper() async {
    if (openingSettings) {
      return;
    }

    setState(() {
      openingSettings = true;
    });

    try {
      await AndroidBridge.openNotificationListenerSettings();
    } catch (error) {
      debugPrint('Failed to open notification listener settings: $error');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      openingSettings = false;
    });
  }

  Future<void> _nextTrack() async {
    _addActivity('⏭ Sending NEXT command...');

    setState(() {
      lastEvent = 'Sending NEXT...';
    });

    final success = await AndroidBridge.spotifyNext();

    if (!mounted) {
      return;
    }

    setState(() {
      lastEvent = success ? 'Next command sent' : 'Next unavailable';
    });

    if (!success) {
      _addActivity('⚠ NEXT unavailable for current session');
    }
  }

  Future<void> _pauseTrack() async {
    _addActivity('⏸ Sending PAUSE command...');

    setState(() {
      lastEvent = 'Sending PAUSE...';
    });

    final success = await AndroidBridge.spotifyPause();

    if (!mounted) {
      return;
    }

    setState(() {
      if (success) {
        isPaused = true;
        lastEvent = 'Playback paused';
      } else {
        lastEvent = 'Pause unavailable';
      }
    });

    if (!success) {
      _addActivity('⚠ PAUSE unavailable for current session');
    }
  }

  Future<void> _playTrack() async {
    _addActivity('▶ Sending PLAY command...');

    setState(() {
      lastEvent = 'Sending PLAY...';
    });

    final success = await AndroidBridge.spotifyPlay();

    if (!mounted) {
      return;
    }

    setState(() {
      if (success) {
        isPaused = false;
        lastEvent = 'Playback resumed';
      } else {
        lastEvent = 'Play unavailable';
      }
    });

    if (!success) {
      _addActivity('⚠ PLAY unavailable for current session');
    }
  }

  Future<void> _togglePlayback() async {
    if (isPaused) {
      await _playTrack();
    } else {
      await _pauseTrack();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),

            SliverToBoxAdapter(child: _buildNowPlaying()),

            SliverToBoxAdapter(child: _buildPlaybackControls()),

            SliverToBoxAdapter(child: _buildDetectionStatus()),

            SliverToBoxAdapter(child: _buildStatistics()),

            SliverToBoxAdapter(child: _buildActivityLog()),

            SliverToBoxAdapter(child: _buildSystemInfo()),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: spotifyGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: spotifyGreen.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.graphic_eq, color: Colors.black, size: 25),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spotify Ad Skipper',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 2),
                Text(
                  'SMART PLAYBACK',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _connectionIndicator(),
        ],
      ),
    );
  }

  Widget _connectionIndicator() {
    final connected = spotifyConnected || notificationListenerEnabled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: connected
            ? spotifyGreen.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: connected
              ? spotifyGreen.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: connected ? spotifyGreen : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            connected ? 'CONNECTED' : 'OFFLINE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: connected ? spotifyGreen : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNowPlaying() {
    final hasTrack = lastTrack.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NOW PLAYING',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF242424), const Color(0xFF171717)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _buildAlbumArt(),
                  const SizedBox(height: 18),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasTrack ? lastTrack : 'Waiting for music',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              hasTrack ? lastArtist : 'Open Spotify to begin',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.favorite_border, color: Colors.grey),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _buildProgressBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1DB954), Color(0xFF087F3E), Color(0xFF121212)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -45,
            right: -35,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -65,
            left: -40,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                spotifyConnected ? Icons.music_note : Icons.graphic_eq,
                size: 72,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                spotifyConnected ? 'SPOTIFY' : 'AD SKIPPER',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: spotifyConnected ? 0.35 : 0,
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 7),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('LIVE', style: TextStyle(fontSize: 9, color: Colors.grey)),
            Text(
              'SPOTIFY SESSION',
              style: TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaybackControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlButton(
            icon: Icons.skip_previous_rounded,
            size: 28,
            onPressed: () {
              _addActivity('⚠ Previous is not connected yet');
            },
          ),

          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: Colors.black,
                size: 34,
              ),
            ),
          ),

          _controlButton(
            icon: Icons.skip_next_rounded,
            size: 32,
            onPressed: _nextTrack,
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required double size,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: size, color: Colors.white),
      splashRadius: 28,
    );
  }

  Widget _buildDetectionStatus() {
    final adDetected = spotifyStatus == 'Advertisement detected';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: adDetected
              ? Colors.orange.withValues(alpha: 0.10)
              : spotifyGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: adDetected
                ? Colors.orange.withValues(alpha: 0.25)
                : spotifyGreen.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: adDetected
                    ? Colors.orange.withValues(alpha: 0.15)
                    : spotifyGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                adDetected ? Icons.warning_amber_rounded : Icons.shield_rounded,
                color: adDetected ? Colors.orange : spotifyGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    adDetected
                        ? 'Advertisement detected'
                        : 'Ad detection active',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    adDetected ? 'Spotify ad event received' : lastEvent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              icon: Icons.block_rounded,
              value: adsDetected.toString(),
              label: 'ADS DETECTED',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              icon: Icons.bolt_rounded,
              value: eventsReceived.toString(),
              label: 'EVENTS',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              icon: Icons.shield_rounded,
              value: notificationListenerEnabled ? 'ON' : 'OFF',
              label: 'PROTECTION',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: spotifyGreen, size: 21),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLog() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, size: 20),
              SizedBox(width: 9),
              Text(
                'Recently detected',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: activityLog.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(
                          Icons.hourglass_empty,
                          color: Colors.grey,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Waiting for Spotify activity...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (int index = 0; index < activityLog.length; index++)
                        _activityRow(
                          activityLog[index],
                          index == activityLog.length - 1,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _activityRow(String activity, bool last) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: spotifyGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activity,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfo() {
    final info = platformInfo;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(Icons.settings_outlined, color: Colors.grey),
          title: const Text(
            'System & Android',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            notificationListenerEnabled
                ? 'Notification access enabled'
                : 'Notification access required',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          children: [
            _systemRow(
              'Manufacturer',
              info?['manufacturer']?.toString() ?? 'Loading...',
            ),
            _systemRow('Model', info?['model']?.toString() ?? 'Loading...'),
            _systemRow(
              'Android',
              info?['androidVersion']?.toString() ?? 'Loading...',
            ),
            _systemRow('SDK', info?['sdkInt']?.toString() ?? 'Loading...'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: openingSettings ? null : _enableSkipper,
                style: FilledButton.styleFrom(
                  backgroundColor: spotifyGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  openingSettings
                      ? 'Opening Settings...'
                      : notificationListenerEnabled
                      ? 'Notification Access Enabled'
                      : 'Enable Notification Access',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _systemRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(Icons.home_filled, 'Home', true),
              _navItem(Icons.analytics_outlined, 'Stats', false),
              _navItem(Icons.shield_outlined, 'Skipper', false),
              _navItem(Icons.settings_outlined, 'Settings', false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool selected) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: selected ? Colors.white : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: selected ? Colors.white : Colors.grey,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
