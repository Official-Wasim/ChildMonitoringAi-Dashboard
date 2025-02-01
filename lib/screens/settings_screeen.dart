import 'package:flutter/material.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import 'dashboard_screen.dart';
import 'recents_screen.dart';
import 'remote_commands_screen.dart';
import 'stats_screen.dart';
import '../theme/theme.dart';

class SettingsController extends ChangeNotifier {
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
  };

  bool getSetting(String key) => _settings[key] ?? false;

  void toggleSetting(String key) {
    if (_settings.containsKey(key)) {
      _settings[key] = !_settings[key]!;
      notifyListeners();
    }
  }
}

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  final SettingsController _controller = SettingsController();
  late AnimationController _settingsAnimationController;

  @override
  void initState() {
    super.initState();
    _settingsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _settingsAnimationController.forward();
  }

  @override
  void dispose() {
    _settingsAnimationController.dispose();
    super.dispose();
  }

  Widget _buildSettingTile(String title, String subtitle, String settingKey) {
    return AnimatedBuilder(
      animation: _settingsAnimationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _settingsAnimationController,
          child: SwitchListTile(
            title: Text(title, style: AppTheme.bodyStyle),
            subtitle: Text(subtitle, style: AppTheme.captionStyle),
            value: _controller.getSetting(settingKey),
            onChanged: (bool value) {
              setState(() {
                _controller.toggleSetting(settingKey);
              });
            },
            activeColor: AppTheme.primaryColor,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.surfaceColor,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Settings', style: AppTheme.headlineStyle),
        backgroundColor: AppTheme.primaryColor,
        shape: AppTheme.appBarTheme.shape,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              elevation: 4,
              child: Column(
                children: [
                  ListTile(
                    title: Text('Communication',
                        style: AppTheme.subtitleStyle
                            .copyWith(fontWeight: FontWeight.bold)),
                  ),
                  _buildSettingTile('SMS Monitoring',
                      'Monitor incoming and outgoing SMS messages', 'sms'),
                  _buildSettingTile(
                      'MMS Monitoring', 'Monitor multimedia messages', 'mms'),
                  _buildSettingTile('Call Monitoring',
                      'Monitor incoming and outgoing calls', 'call'),
                  _buildSettingTile(
                      'Call Recording', 'Record phone calls', 'callRecording'),
                ],
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Column(
                children: [
                  ListTile(
                    title: Text('Location & Activity',
                        style: AppTheme.subtitleStyle
                            .copyWith(fontWeight: FontWeight.bold)),
                  ),
                  _buildSettingTile(
                      'Location Tracking', 'Track device location', 'location'),
                  _buildSettingTile('App Monitoring',
                      'Monitor app usage and activity', 'apps'),
                  _buildSettingTile(
                      'Web Monitoring', 'Monitor website visits', 'sites'),
                ],
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Column(
                children: [
                  ListTile(
                    title: Text('Other Monitoring',
                        style: AppTheme.subtitleStyle
                            .copyWith(fontWeight: FontWeight.bold)),
                  ),
                  _buildSettingTile(
                      'Contacts', 'Monitor contact list changes', 'contacts'),
                  _buildSettingTile('Screenshot',
                      'Capture periodic screenshots', 'screenshot'),
                  _buildSettingTile('Instant Messaging',
                      'Monitor messaging apps', 'instantMessaging'),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: 4, // Settings tab
        items: [
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
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                if (index == 0) {
                  return DashboardScreen();
                } else if (index == 1) {
                  return RecentsScreen();
                } else if (index == 2) {
                  return const RemoteControlScreen();
                } else if (index == 3) {
                  return const AdvancedStatsScreen();
                } else {
                  return SettingsScreen();
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
      ),
    );
  }
}
