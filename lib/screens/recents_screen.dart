import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import '../theme/theme.dart';
import 'dashboard_screen.dart';
import 'stats_screen.dart';
import 'settings_screeen.dart';
import 'remote_commands_screen.dart';

class RecentsScreen extends StatefulWidget {
  const RecentsScreen({Key? key}) : super(key: key);

  @override
  State<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends State<RecentsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();
  int _page = 1; // Set to 1 since this is the Recents tab

  late TabController _tabController;
  final List<Map<String, dynamic>> notifications = [
    {
      'title': 'New App Installed',
      'description': 'TikTok was installed on device',
      'time': DateTime.now().subtract(const Duration(minutes: 30)),
      'type': 'app',
      'risk': 'medium',
    },
    {
      'title': 'Suspicious Activity',
      'description': 'Attempted access to blocked website',
      'time': DateTime.now().subtract(const Duration(hours: 1)),
      'type': 'security',
      'risk': 'high',
    },
    {
      'title': 'Screen Time Alert',
      'description': 'Daily limit reached for Gaming apps',
      'time': DateTime.now().subtract(const Duration(hours: 2)),
      'type': 'time',
      'risk': 'low',
    },
  ];

  final List<Map<String, dynamic>> locationData = [
    {'time': '08:00', 'location': 'Home', 'duration': '2h'},
    {'time': '10:00', 'location': 'School', 'duration': '6h'},
    {'time': '16:00', 'location': 'Park', 'duration': '1h'},
    {'time': '17:00', 'location': 'Home', 'duration': 'Current'},
  ];

  final Map<String, double> appUsage = {
    'Social Media': 120,
    'Education': 90,
    'Gaming': 60,
    'Entertainment': 45,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        appBar: AppBar(
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
          title: Text(
            "Recent Activity",
            style: AppTheme.headlineStyle,
          ),
          shape: AppTheme.appBarTheme.shape,
        ),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: SizedBox(height: 16), // Add spacing here
              ),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: CurvedNavigationBar(
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
                      return RecentsScreen();
                    case 2:
                      return RemoteControlScreen();
                    case 3:
                      return AdvancedStatsScreen();
                    case 4:
                      return SettingsScreen();
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
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      pinned: true,
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
      title: Text('Recent Activity', style: AppTheme.headlineStyle),
      shape: AppTheme.appBarTheme.shape,
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
            AppTheme.primaryColor.withOpacity(0.8)
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
          Text(
            'Today\'s Overview',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickStatItem(
                'Screen Time',
                '4h 30m',
                Icons.access_time_rounded,
              ),
              _buildQuickStatItem(
                'App Opens',
                '24',
                Icons.apps_rounded,
              ),
              _buildQuickStatItem(
                'Alerts',
                '3',
                Icons.warning_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem(String title, String value, IconData icon) {
    return Column(
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
    );
  }

  Widget _buildNotificationsSection() {
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
          Text(
            'Recent Alerts',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ...notifications
              .map((notification) => _buildNotificationCard(notification)),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    Color getRiskColor() {
      switch (notification['risk']) {
        case 'high':
          return Colors.red[400]!;
        case 'medium':
          return Colors.orange[400]!;
        default:
          return Colors.green[400]!;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getRiskColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: getRiskColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: getRiskColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getNotificationIcon(notification['type']),
              color: getRiskColor(),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification['title'],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  notification['description'],
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  _getTimeAgo(notification['time']),
                  style: GoogleFonts.poppins(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          Text(
            'Location Timeline',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
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

  Widget _buildTimelineItem(Map<String, dynamic> data, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            data['time'],
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
                color: Colors.blue,
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
                color: Colors.blue.withOpacity(0.2),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['location'],
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                data['duration'],
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              SizedBox(height: isLast ? 0 : 30),
            ],
          ),
        ),
      ],
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
          Text(
            'App Usage',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ...appUsage.entries
              .map((entry) => _buildUsageLegendItem(
                    entry.key,
                    entry.value,
                    _getCategoryColor(entry.key),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildUsageLegendItem(String category, double minutes, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${minutes.toInt()} min',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
