import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/recents_screen/fetch_recent_data.dart';
import '../services/stats_screen/fetch_stats_data.dart'; // Add this import
import '../theme/theme.dart';
import 'dashboard_screen.dart';
import 'settings_screeen.dart';
import 'stats_screen.dart';
import 'remote_commands_screen.dart';
import '../services/recents_screen/preferences_set.dart';

// Data Models
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime timestamp;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
  });

  Color get typeColor {
    switch (type.toLowerCase()) {
      case 'geofence_alert':
        return Colors.blue;
      case 'alert':
        return Colors.green;
      case 'web_alert':
        return Colors.red;
      case 'app_install':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class LocationEntry {
  final String time;
  final String location;
  final String action;
  final DateTime timestamp;

  LocationEntry({
    required this.time,
    required this.location,
    required this.action,
    required this.timestamp,
  });
}

class AppUsageData {
  final String category;
  final double minutes;
  final int openCount;
  final DateTime lastUsed;

  AppUsageData({
    required this.category,
    required this.minutes,
    required this.openCount,
    required this.lastUsed,
  });
}

class RecentsScreen extends StatefulWidget {
  final String selectedDevice;

  const RecentsScreen({
    Key? key,
    required this.selectedDevice,
  }) : super(key: key);

  @override
  State<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends State<RecentsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();
  int _page = 1;
  late TabController _tabController;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String _selectedDevice = 'Select Device';
  int _screenTimeMinutes = 0;
  int _appsUsed = 0;
  int _alertsCount = 0; // Add this line
  List<NotificationItem> notifications = [];
  List<LocationEntry> locationData = [];
  List<AppUsageData> appUsage = []; // Add this line

  // Add these stream subscription variables
  List<StreamSubscription> _subscriptions = [];
  bool _disposed = false;

  // Add this at the top with other instance variables
  final UserStatsService _statsService = UserStatsService();

  // Add this state variable
  bool _showAllNotifications = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDevice = widget.selectedDevice;
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    // Initial load
    _loadData();
    _loadNotifications();
    _loadGeofenceTimeline();

    // Setup real-time listeners
    if (_selectedDevice != 'Select Device') {
      _setupNotificationsListener();
      _setupGeofenceListener();
    }
  }

  void _setupNotificationsListener() {
    final notificationsStream = FirebaseDatabase.instance
        .ref()
        .child(
            'users/${FirebaseAuth.instance.currentUser?.uid}/phones/$_selectedDevice/notifications')
        .onValue;

    final subscription = notificationsStream.listen((event) {
      if (!_disposed) {
        _loadNotifications();
      }
    });

    _subscriptions.add(subscription);
  }

  void _setupGeofenceListener() {
    final geofenceStream = FirebaseDatabase.instance
        .ref()
        .child(
            'users/${FirebaseAuth.instance.currentUser?.uid}/phones/$_selectedDevice/preferences/geofences')
        .onValue;

    final subscription = geofenceStream.listen((event) {
      if (!_disposed) {
        _loadGeofenceTimeline();
      }
    });

    _subscriptions.add(subscription);
  }

  Future<void> _loadSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final device = prefs.getString('selected_device');
    if (device != null) {
      setState(() {
        _selectedDevice = device;
      });
    }
  }

  Future<void> _loadData() async {
    if (_disposed) return;

    _safeSetState(() => _isLoading = true);
    try {
      if (_selectedDevice != 'Select Device') {
        final overview = await _statsService.fetchTodaysOverview(
          FirebaseAuth.instance.currentUser!.uid,
          _selectedDevice,
          _selectedDate,
        );

        _safeSetState(() {
          _screenTimeMinutes = overview['screenTime'];
          _appsUsed = overview['appsUsed'];
          _alertsCount =
              overview['alertsCount']; // This will now get the correct count
        });
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  Future<void> _loadNotifications() async {
    if (_disposed || _selectedDevice == 'Select Device') return;

    final alertsList = await FetchDataService.fetchRecentAlerts(
      _selectedDevice,
      _selectedDate,
    );
    _safeSetState(() {
      notifications = alertsList
          .map((alert) => NotificationItem(
                id: alert['id'],
                title: alert['title'],
                body: alert['body'],
                type: alert['type'],
                timestamp:
                    DateTime.fromMillisecondsSinceEpoch(alert['timestamp']),
              ))
          .toList();
    });
  }

  Future<void> _loadGeofenceTimeline() async {
    if (_disposed || _selectedDevice == 'Select Device') return;

    final timeline = await FetchDataService.fetchGeofenceTimeline(
      _selectedDevice,
      _selectedDate,
    );
    _safeSetState(() {
      locationData = timeline
          .map((entry) => LocationEntry(
                time: DateFormat('HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(entry['time'] as int)),
                location: entry['location'],
                action: entry['action'],
                timestamp:
                    DateTime.fromMillisecondsSinceEpoch(entry['time'] as int),
              ))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_page != 0) {
          setState(() => _page = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FF),
        extendBodyBehindAppBar: false,
        appBar: _buildAppBar(),
        body: _isLoading ? _buildLoadingView() : _buildMainContent(),
        bottomNavigationBar: _buildBottomNavigation(),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppTheme.primaryColor,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppTheme.surfaceColor,
          size: 22,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text("Recent Activity", style: AppTheme.headlineStyle),
      actions: [
        IconButton(
          icon: Icon(
            Icons.calendar_today_rounded,
            color: AppTheme.surfaceColor,
          ),
          onPressed: () => _showDatePicker(),
        ),
        IconButton(
          icon: Icon(
            Icons.notifications_active_outlined,
            color: AppTheme.surfaceColor,
          ),
          onPressed: () => _showSetAlerts(),
        ),
      ],
      shape: AppTheme.appBarTheme.shape,
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildQuickStats(),
                    const SizedBox(height: 24),
                    _buildNotificationsSection(),
                    const SizedBox(height: 24),
                    _buildLocationTimeline(),
                    const SizedBox(height: 24),
                    _buildAppUsageList(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Overview',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white),
                onPressed: () => _showOverviewInfo(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickStatItem(
                'Screen Time',
                '${_formatScreenTime(_screenTimeMinutes)}',
                Icons.access_time_rounded,
                onTap: () => _showScreenTimeDetails(),
              ),
              _buildQuickStatItem(
                'Apps Used', // Changed from 'App Opens'
                '$_appsUsed', // Use the new value
                Icons.apps_rounded,
                onTap: () => _showAppOpenDetails(),
              ),
              _buildQuickStatItem(
                'Alerts',
                '$_alertsCount', // Use the real count here
                Icons.warning_rounded,
                onTap: () => _showAlertDetails(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem(
    String title,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    final displayedNotifications =
        _showAllNotifications ? notifications : notifications.take(6).toList();
    final remainingCount = notifications.length - 6;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Alerts',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (notifications.length > 6)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showAllNotifications = !_showAllNotifications;
                    });
                  },
                  child: Text(
                    _showAllNotifications
                        ? 'Show less'
                        : 'View all ($remainingCount more)',
                    style: GoogleFonts.poppins(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (notifications.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recent alerts found',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Alerts will appear here when detected',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ...displayedNotifications
                .map((notification) => _buildNotificationCard(notification)),
          if (_showAllNotifications && notifications.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showAllNotifications = false;
                    });
                  },
                  child: Text(
                    'Show less',
                    style: GoogleFonts.poppins(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    return GestureDetector(
      onTap: () => _showNotificationDetails(notification),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.typeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification.typeColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: notification.typeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getNotificationIcon(notification.type),
                color: notification.typeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    notification.body,
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _getTimeAgo(notification.timestamp),
                    style: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTimeline() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Geofence Timeline',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => _showLocationHistory(),
                child: Text(
                  'View Map',
                  style: GoogleFonts.poppins(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (locationData.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No geofence activity found',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Location updates will appear here',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ...locationData.asMap().entries.map(
                  (entry) => _buildTimelineItem(
                    entry.value,
                    isLast: entry.key == locationData.length - 1,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(LocationEntry data, {bool isLast = false}) {
    return GestureDetector(
      onTap: () => _showLocationDetails(data),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              data.time,
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: data.action == 'Entered' ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 50,
                  color: AppTheme.primaryColor.withOpacity(0.2),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.location,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  data.action,
                  style: GoogleFonts.poppins(
                    color: data.action == 'Entered' ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isLast ? 0 : 30),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }

  Widget _buildAppUsageList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'App Usage',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => _showDetailedUsageStats(),
                child: Text(
                  'Details',
                  style: GoogleFonts.poppins(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (appUsage.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.apps_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No app usage data available',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'App activity will be shown here',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ...appUsage.map((usage) => _buildUsageLegendItem(usage)),
        ],
      ),
    );
  }

  Widget _buildUsageLegendItem(AppUsageData usage) {
    return GestureDetector(
      onTap: () => _showCategoryDetails(usage),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getCategoryColor(usage.category),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usage.category,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${usage.openCount} opens',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${usage.minutes.toInt()} min',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  _getTimeAgo(usage.lastUsed),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      backgroundColor: AppTheme.primaryColor,
      child: const Icon(Icons.add_rounded,
          color: Colors.white), // Change icon color to white
      onPressed: () => _showActionsMenu(),
    );
  }

  Widget _buildBottomNavigation() {
    return CurvedNavigationBar(
      key: _bottomNavigationKey,
      index: _page,
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
      onTap: _handleNavigation,
      letIndexChange: (index) => true,
    );
  }

  // Navigation and Action Handlers
  void _handleNavigation(int index) {
    if (index == _page) return;

    setState(() => _page = index);
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          switch (index) {
            case 0:
              return DashboardScreen();
            case 1:
              return RecentsScreen(selectedDevice: _selectedDevice);
            case 2:
              return RemoteControlScreen(selectedDevice: _selectedDevice);
            case 3:
              return AdvancedStatsScreen(selectedDevice: _selectedDevice);
            case 4:
              return SettingsScreen(selectedDevice: _selectedDevice);
            default:
              return DashboardScreen();
          }
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  // Helper Methods
  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'app':
        return Icons.apps_rounded;
      case 'security':
        return Icons.security_rounded;
      case 'time':
        return Icons.timer_rounded;
      case 'location':
        return Icons.location_on_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(time);
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Social Media':
        return Colors.blue[400]!;
      case 'Education':
        return Colors.green[400]!;
      case 'Gaming':
        return Colors.purple[400]!;
      case 'Entertainment':
        return Colors.orange[400]!;
      default:
        return Colors.grey[400]!;
    }
  }

  String _formatScreenTime(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  String _formatPreferenceKey(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  // Dialog and Modal Methods
  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 4)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      // Reload all data for the new date
      await _loadData();
      await _loadNotifications();
      await _loadGeofenceTimeline();
    }
  }

  void _showSetAlerts() async {
    // Get current preferences
    try {
      final prefs = await PreferencesService.getAlertPreferences(
        deviceId: _selectedDevice,
      );

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active,
                          color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        'Activity Alerts',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      ...prefs.entries.map(
                        (entry) => SwitchListTile(
                          title: Text(
                            _formatPreferenceKey(entry.key),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            _getPreferenceDescription(entry.key),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          value: entry.value,
                          onChanged: (value) async {
                            await PreferencesService.updateSinglePreference(
                              deviceId: _selectedDevice,
                              preference: entry.key,
                              value: value,
                            );
                            setState(() {
                              prefs[entry.key] = value;
                            });
                          },
                          activeColor: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Alert preferences updated successfully'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Save',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load preferences: $e')),
      );
    }
  }

  String _getPreferenceDescription(String key) {
    switch (key) {
      case 'new_app_install':
        return 'Notify when new apps are installed';
      case 'screen_time_limit':
        return 'Alert when daily screen time limit is reached';
      case 'geofence':
        return 'Notify when device enters/exits set locations';
      case 'suspicious_content':
        return 'Alert for potentially harmful content';
      case 'late_night_activity':
        return 'Notify of device usage during late hours';
      case 'blocked_website':
        return 'Alert when blocked websites are accessed';
      case 'suspicious_search':
        return 'Notify of concerning search terms';
      default:
        return '';
    }
  }

  void _showOverviewInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Overview Information',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: const Text('Details about the overview metrics...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Additional helper methods would go here...

  void _showScreenTimeDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Screen Time Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: const Text('Detailed information about screen time usage...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNotificationDetails(NotificationItem notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          notification.title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body),
            const SizedBox(height: 8),
            Text(
              'Type: ${notification.type}',
              style: TextStyle(
                color: notification.typeColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Time: ${DateFormat('MMM d, yyyy h:mm a').format(notification.timestamp)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showActionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Refresh Data'),
              onTap: () {
                Navigator.pop(context);
                _refreshData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Set Activity Alerts'),
              onTap: () {
                Navigator.pop(context);
                _showSetAlerts();
              },
            ),
            ListTile(
              leading: const Icon(Icons.web),
              title: const Text('Set Website Alerts'),
              onTap: () {
                Navigator.pop(context);
                _showWebsiteAlertSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.apps),
              title: const Text('Set App Usage Limits'),
              onTap: () {
                Navigator.pop(context);
                _showAppUsageLimitSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Set Geofence Alerts'),
              onTap: () {
                Navigator.pop(context);
                _showGeofenceSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('Set Keyword Alerts for messages'),
              onTap: () {
                Navigator.pop(context);
                _showKeywordAlertSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showKeywordAlertSettings() {
    final _keywordController = TextEditingController();
    String _errorMessage = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: FutureBuilder<List<String>>(
          future: PreferencesService.getKeywordAlerts(_selectedDevice),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final keywords = snapshot.data ?? [];

            return StatefulBuilder(
              builder: (context, setState) => Container(
                padding: const EdgeInsets.all(24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Keyword Alerts',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    if (_errorMessage.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: GoogleFonts.poppins(
                                  color: Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _keywordController,
                      decoration: InputDecoration(
                        labelText: 'Add Keyword',
                        hintText: 'Enter keyword to monitor',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.add, color: AppTheme.primaryColor),
                          onPressed: () async {
                            final keyword = _keywordController.text.trim();
                            if (keyword.isEmpty) {
                              setState(() =>
                                  _errorMessage = 'Please enter a keyword');
                              return;
                            }
                            try {
                              await PreferencesService.addKeywordAlert(
                                deviceId: _selectedDevice,
                                keyword: keyword,
                              );
                              _keywordController.clear();
                              Navigator.pop(context);
                              _showKeywordAlertSettings();
                              showMessage('Keyword added successfully');
                            } catch (e) {
                              setState(() => _errorMessage = e.toString());
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Monitored Keywords',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: keywords.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No keywords added',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: keywords.length,
                              itemBuilder: (context, index) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: Icon(Icons.key,
                                        color: AppTheme.primaryColor),
                                    title: Text(keywords[index]),
                                    trailing: IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          color: Colors.red[400]),
                                      onPressed: () async {
                                        try {
                                          await PreferencesService
                                              .removeKeywordAlert(
                                            deviceId: _selectedDevice,
                                            keyword: keywords[index],
                                          );
                                          Navigator.pop(context);
                                          _showKeywordAlertSettings();
                                          showMessage(
                                              'Keyword removed successfully');
                                        } catch (e) {
                                          setState(() =>
                                              _errorMessage = e.toString());
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showWebsiteAlertSettings() {
    final _keywordController = TextEditingController();
    final _urlController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: FutureBuilder<Map<String, List<String>>>(
          future: PreferencesService.getWebAlerts(_selectedDevice),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final webAlerts = snapshot.data ?? {'keywords': [], 'urls': []};

            return Container(
              padding: const EdgeInsets.all(24),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Website Alerts',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Keywords Section
                  TextField(
                    controller: _keywordController,
                    decoration: InputDecoration(
                      labelText: 'Add Keyword to Block',
                      hintText: 'Enter keyword to flag',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.add, color: AppTheme.primaryColor),
                        onPressed: () async {
                          if (_keywordController.text.isNotEmpty) {
                            await PreferencesService.addWebAlert(
                              deviceId: _selectedDevice,
                              type: 'keywords',
                              value: _keywordController.text.trim(),
                            );
                            _keywordController.clear();
                            Navigator.pop(context);
                            _showWebsiteAlertSettings(); // Refresh dialog
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // URLs Section
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'Add Website to Block',
                      hintText: 'Enter domain (e.g., example.com)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.add, color: AppTheme.primaryColor),
                        onPressed: () async {
                          if (_urlController.text.isNotEmpty) {
                            await PreferencesService.addWebAlert(
                              deviceId: _selectedDevice,
                              type: 'urls',
                              value: _urlController.text.trim(),
                            );
                            _urlController.clear();
                            Navigator.pop(context);
                            _showWebsiteAlertSettings(); // Refresh dialog
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Blocked Items Section
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            tabs: [
                              Tab(
                                  text:
                                      'Keywords (${webAlerts['keywords']?.length ?? 0})'),
                              Tab(
                                  text:
                                      'Websites (${webAlerts['urls']?.length ?? 0})'),
                            ],
                            labelColor: AppTheme.primaryColor,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildBlockedList(
                                  items: webAlerts['keywords'] ?? [],
                                  type: 'keywords',
                                  icon: Icons.label_outline,
                                ),
                                _buildBlockedList(
                                  items: webAlerts['urls'] ?? [],
                                  type: 'urls',
                                  icon: Icons.link,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBlockedList({
    required List<String> items,
    required String type,
    required IconData icon,
  }) {
    return items.isEmpty
        ? Center(
            child: Text(
              'No blocked ${type == 'keywords' ? 'keywords' : 'websites'} yet',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          )
        : ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(icon, color: AppTheme.primaryColor),
                  title: Text(
                    items[index],
                    style: GoogleFonts.poppins(),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      await PreferencesService.removeWebAlert(
                        deviceId: _selectedDevice,
                        type: type,
                        value: items[index],
                      );
                      Navigator.pop(context);
                      _showWebsiteAlertSettings(); // Refresh dialog
                    },
                  ),
                ),
              );
            },
          );
  }

  void _showAppUsageLimitSettings() {
    final _appNameController = TextEditingController();
    final _packageNameController = TextEditingController();
    int _selectedHours = 2;
    int _selectedMinutes = 30;
    String _errorMessage = '';
    List<Map<String, dynamic>> _suggestions = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: PreferencesService.getAppLimits(_selectedDevice),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final appLimits = snapshot.data ?? [];

            return StatefulBuilder(
              builder: (context, setState) => Container(
                padding: const EdgeInsets.all(24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'App Usage Limits',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Error message section
                    if (_errorMessage.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: GoogleFonts.poppins(
                                  color: Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Inputs section
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // App Name Input
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _appNameController,
                                  onChanged: (value) async {
                                    if (value.length >= 2) {
                                      final suggestions =
                                          await PreferencesService
                                              .getInstalledAppSuggestions(
                                        _selectedDevice,
                                        value,
                                      );
                                      setState(() {
                                        _suggestions = suggestions;
                                      });
                                    } else {
                                      setState(() {
                                        _suggestions = [];
                                      });
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'App Name',
                                    hintText: 'Start typing app name...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: Icon(Icons.apps),
                                  ),
                                ),
                                if (_suggestions.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: Colors.grey[300]!),
                                    ),
                                    constraints: BoxConstraints(
                                      maxHeight: 200,
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _suggestions.length,
                                      itemBuilder: (context, index) {
                                        final suggestion = _suggestions[index];
                                        return ListTile(
                                          dense: true,
                                          title: Text(suggestion['appName']),
                                          subtitle:
                                              Text(suggestion['packageName']),
                                          onTap: () {
                                            setState(() {
                                              _appNameController.text =
                                                  suggestion['appName'];
                                              _packageNameController.text =
                                                  suggestion['packageName'];
                                              _suggestions = [];
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _packageNameController,
                              enabled: false, // Make it read-only
                              decoration: InputDecoration(
                                labelText: 'Package Name',
                                hintText: 'Auto-filled when app is selected',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: Icon(Icons.code),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Time Selection
                            StatefulBuilder(
                              builder: (context, setState) => Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Hours',
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                          SizedBox(
                                            height: 60,
                                            child: CupertinoPicker(
                                              itemExtent: 32,
                                              onSelectedItemChanged: (index) {
                                                setState(() =>
                                                    _selectedHours = index);
                                              },
                                              children: List.generate(
                                                24,
                                                (index) => Center(
                                                  child: Text(
                                                    '$index',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      color:
                                                          AppTheme.primaryColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Minutes',
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                          SizedBox(
                                            height: 60,
                                            child: CupertinoPicker(
                                              itemExtent: 32,
                                              onSelectedItemChanged: (index) {
                                                setState(() =>
                                                    _selectedMinutes = index);
                                              },
                                              children: List.generate(
                                                60,
                                                (index) => Center(
                                                  child: Text(
                                                    '$index',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      color:
                                                          AppTheme.primaryColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Current Limits Section
                            Text(
                              'Current Limits',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // App limits list
                            ...appLimits
                                .map((limit) => Card(
                                      elevation: 2,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.timer,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        title: Text(
                                          limit['appName'],
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${limit['hours']}h ${limit['minutes']}m daily',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Colors.red[400],
                                          ),
                                          onPressed: () async {
                                            await PreferencesService
                                                .removeAppLimit(
                                              deviceId: _selectedDevice,
                                              appName: limit['appName'],
                                            );
                                            Navigator.pop(context);
                                            _showAppUsageLimitSettings();
                                          },
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ],
                        ),
                      ),
                    ),

                    // Bottom buttons
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final appName = _appNameController.text.trim();
                          final packageName =
                              _packageNameController.text.trim();

                          if (appName.isEmpty || packageName.isEmpty) {
                            setState(() => _errorMessage =
                                'Please select an app from the suggestions');
                            return;
                          }

                          try {
                            await PreferencesService.addAppLimit(
                              deviceId: _selectedDevice,
                              appName: appName,
                              packageName: packageName,
                              hours: _selectedHours,
                              minutes: _selectedMinutes,
                            );

                            Navigator.pop(context);
                            _showAppUsageLimitSettings();
                            showMessage('App limit set successfully');
                          } catch (e) {
                            setState(() => _errorMessage = e.toString());
                          }
                        },
                        child: Text(
                          'Set Limit',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showGeofenceSettings() {
    final _nameController = TextEditingController();
    final _latController = TextEditingController();
    final _lngController = TextEditingController();
    final _radiusController = TextEditingController();
    String _errorMessage = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: PreferencesService.getGeofences(_selectedDevice),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final geofences = snapshot.data ?? [];

            return StatefulBuilder(
              builder: (context, setState) => Container(
                padding: const EdgeInsets.all(24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Geofence Alerts',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Fence Name',
                                hintText: 'Enter Fence name',
                                prefixIcon: Icon(Icons.location_on),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _latController,
                                    decoration: InputDecoration(
                                      labelText: 'Latitude',
                                      hintText: '00.0000',
                                      prefixIcon: Icon(Icons.explore),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                            decimal: true),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _lngController,
                                    decoration: InputDecoration(
                                      labelText: 'Longitude',
                                      hintText: '00.0000',
                                      prefixIcon: Icon(Icons.explore_outlined),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                            decimal: true),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _radiusController,
                                    decoration: InputDecoration(
                                      labelText: 'Radius (meters)',
                                      hintText: 'Enter radius',
                                      prefixIcon:
                                          Icon(Icons.radio_button_checked),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                          vertical: 20,
                                          horizontal: 12), // Adjust padding
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  icon: Icon(Icons.map, color: Colors.white),
                                  label: Text('Pick on Map',
                                      style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    // TODO: Implement map picker
                                    showMessage(
                                        'Map picker will be implemented soon');
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Active Geofences',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (geofences.isEmpty)
                              Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.location_off_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No geofences set',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...geofences.map((fence) => Card(
                                    margin: EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.location_on,
                                            color: AppTheme.primaryColor),
                                      ),
                                      title: Text(
                                        fence['name'],
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500),
                                      ),
                                      subtitle: Text(
                                        'Radius: ${fence['radius']}m',
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(Icons.delete_outline,
                                            color: Colors.red[400]),
                                        onPressed: () async {
                                          try {
                                            await PreferencesService
                                                .removeGeofence(
                                              deviceId: _selectedDevice,
                                              name: fence['name'],
                                            );
                                            Navigator.pop(context);
                                            _showGeofenceSettings();
                                            showMessage(
                                                'Geofence removed successfully');
                                          } catch (e) {
                                            setState(() =>
                                                _errorMessage = e.toString());
                                          }
                                        },
                                      ),
                                    ),
                                  )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          try {
                            final name = _nameController.text.trim();
                            final lat = double.tryParse(_latController.text);
                            final lng = double.tryParse(_lngController.text);
                            final radius = int.tryParse(_radiusController.text);

                            if (name.isEmpty) {
                              throw Exception('Please enter a location name');
                            }
                            if (lat == null || lng == null) {
                              throw Exception(
                                  'Please enter valid latitude and longitude');
                            }
                            if (radius == null || radius <= 0) {
                              throw Exception('Please enter a valid radius');
                            }

                            await PreferencesService.addGeofence(
                              deviceId: _selectedDevice,
                              name: name,
                              latitude: lat,
                              longitude: lng,
                              radius: radius,
                            );

                            Navigator.pop(context);
                            _showGeofenceSettings();
                            showMessage('Geofence added successfully');
                          } catch (e) {
                            setState(() => _errorMessage = e.toString());
                          }
                        },
                        child: Text(
                          'Add Geofence',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCategoryDetails(AppUsageData usage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${usage.category} Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usage Time: ${usage.minutes.toInt()} minutes'),
            Text('Open Count: ${usage.openCount}'),
            Text('Last Used: ${_getTimeAgo(usage.lastUsed)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDetailedUsageStats() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Detailed Usage Statistics',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Total Screen Time: ${appUsage.fold<double>(0, (sum, item) => sum + item.minutes).toInt()} minutes'),
            Text(
                'Total App Opens: ${appUsage.fold<int>(0, (sum, item) => sum + item.openCount)}'),
            const SizedBox(height: 16),
            const Text('Tap on individual categories for more details.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLocationHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Location History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Location history will be displayed here...'),
            // Add map or location history UI here
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLocationDetails(LocationEntry data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Geofence Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time: ${data.time}'),
            Text('Location: ${data.location}'),
            Text(
              'Action: ${data.action}',
              style: TextStyle(
                color: data.action == 'Entered' ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text('Date: ${DateFormat('MMM d, yyyy').format(data.timestamp)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAppOpenDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'App Opens Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Details about app opens and launch frequency...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAlertDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Alert Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Alerts: ${notifications.length}'),
            const SizedBox(height: 8),
            Text(
                'High Risk: ${notifications.where((n) => n.type == 'high').length}'),
            Text(
                'Medium Risk: ${notifications.where((n) => n.type == 'medium').length}'),
            Text(
                'Low Risk: ${notifications.where((n) => n.type == 'low').length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _tabController.dispose();
    super.dispose();
  }

  // Add this method for safe state updates
  void _safeSetState(VoidCallback fn) {
    if (!_disposed && mounted) {
      setState(fn);
    }
  }
}
