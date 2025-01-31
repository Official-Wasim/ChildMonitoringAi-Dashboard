import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'dashboard_screen.dart';
import 'recents_screen.dart';
import 'settings_screeen.dart';
import 'remote_commands_screen.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/charts/stats_chart.dart';
import '../components/charts/stats_cards.dart';
import '../theme/theme.dart';

class AdvancedStatsScreen extends StatefulWidget {
  const AdvancedStatsScreen({Key? key}) : super(key: key);

  @override
  State<AdvancedStatsScreen> createState() => _AdvancedStatsScreenState();
}

class _AdvancedStatsScreenState extends State<AdvancedStatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTimeRange = 0; // 0: Today, 1: Week, 2: Month
  final List<String> _timeRanges = ['Today', 'Week', 'Month'];

  // Add this style definition
  final TextStyle _headlineStyle = const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: Colors.black87,
  );

  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();
  int _page = 3; // Set to 3 since this is the Stats tab

  String? _selectedPhoneModel;
  List<String> _phoneModels = [];
  bool _isLoading = true;

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;

  // Add these variables
  Map<String, dynamic> _callStats = {
    'incoming': 0,
    'outgoing': 0,
    'missed': 0,
    'totalDuration': 0,
    'totalCalls': 0,
  };

  List<Map<String, dynamic>> _callDetails = [];

  // Add this variable
  int _totalMessagesCount = 0;
  double _messageTrend = 0;
  double _callTrend = 0;

  // Add this variable to store web visits data
  List<ChartData> _webVisitsData = [];

  final StatsService _statsService = StatsService();

  // Add these variables after other state variables
  final List<ScreenTimeData> _screenTimeData = [
    ScreenTimeData('Mon', 3),
    ScreenTimeData('Tue', 4),
    ScreenTimeData('Wed', 3.5),
    ScreenTimeData('Thu', 5),
    ScreenTimeData('Fri', 4),
    ScreenTimeData('Sat', 6),
    ScreenTimeData('Sun', 5),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSelectedDevice(); // Add this line
    _initializeUser();
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  Future<void> _initializeUser() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        _userId = user.uid;
        await _fetchDevices();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in!')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error initializing user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch user data.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDevice = prefs.getString('selected_device');
    if (savedDevice != null && mounted) {
      setState(() {
        _selectedPhoneModel = savedDevice;
      });
    }
  }

  Future<void> _fetchDevices() async {
    if (_userId == null || !mounted) return;

    try {
      final phonesSnapshot =
          await _databaseRef.child('users/$_userId/phones').get();
      if (phonesSnapshot.exists) {
        final prefs = await SharedPreferences.getInstance();
        final savedDevice = prefs.getString('selected_device');

        if (mounted) {
          setState(() {
            _phoneModels = phonesSnapshot.children.map((e) => e.key!).toList();
            // Use saved device if available and valid, otherwise use first device
            if (savedDevice != null && _phoneModels.contains(savedDevice)) {
              _selectedPhoneModel = savedDevice;
            } else {
              _selectedPhoneModel =
                  _phoneModels.isNotEmpty ? _phoneModels.first : null;
            }
          });
          if (_selectedPhoneModel != null) {
            _fetchStatsData(); // Fetch initial data for the first device
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching devices: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading devices.')),
        );
      }
    }
  }

  Future<void> _fetchStatsData() async {
    if (_userId == null || _selectedPhoneModel == null || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final stats =
          await _statsService.fetchStatsData(_userId!, _selectedPhoneModel!);

      if (mounted) {
        setState(() {
          _callStats = stats['callStats'];
          _callDetails = _callStats['details'];

          final messageStats = stats['messageStats'];
          _totalMessagesCount = messageStats['current']['total'];
          _messageTrend = messageStats['trend'];

          _webVisitsData = stats['webVisits'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading statistics.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Add this method before build()
  void _showTrendInfo(BuildContext context, String title, String value,
      IconData icon, Color color, String trend) {
    String numericValue =
        trend.replaceAll('+', '').replaceAll('-', '').replaceAll('%', '');
    bool isIncrease = trend.startsWith('+');
    Color trendColor = isIncrease ? Colors.green : Colors.red;

    int todayCount = int.tryParse(value) ?? 0;
    double percentageChange = double.tryParse(numericValue) ?? 0;
    int yesterdayCount = (todayCount * 100 / (100 + percentageChange)).round();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Today: $todayCount'),
              Text('Yesterday: $yesterdayCount'),
              Text('Change: $trend'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return WillPopScope(
      onWillPop: () async {
        if (_page != 0) {
          setState(() => _page = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        extendBodyBehindAppBar: false, // Changed to false
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
            "Statistics",
            style: AppTheme.headlineStyle,
          ),
          shape: AppTheme.appBarTheme.shape,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(60), // Adjusted height
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 12,
                top: 12,
              ),
              child: _buildDeviceSelector(), // Always show the device selector
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    Container(
                      margin: EdgeInsets.all(constraints.maxWidth * 0.04),
                      padding: EdgeInsets.all(constraints.maxWidth * 0.04),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _buildTimeRangeSelector(),
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth * 0.04,
                          vertical: constraints.maxWidth * 0.02),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          highlightColor: Colors.transparent,
                          splashColor: Colors.transparent,
                        ),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true, // Changed to false
                          indicator: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          labelStyle: const TextStyle(
                            fontSize: 13, // Reduced font size
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3, // Reduced letter spacing
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 12, // Reduced font size
                            fontWeight: FontWeight.w500,
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey[600],
                          indicatorPadding: const EdgeInsets.all(4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          tabs: [
                            _buildTab(Icons.dashboard_outlined, 'Overview'),
                            _buildTab(Icons.message_outlined, 'Chats'),
                            _buildTab(Icons.apps_outlined, 'Apps'),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(constraints),
                          _buildCommunicationTab(constraints),
                          _buildAppStatsTab(constraints),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        bottomNavigationBar: CurvedNavigationBar(
          key: _bottomNavigationKey,
          index: _page,
          items: const [
            // Add const to prevent rebuilds
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

  Widget _buildDeviceSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPhoneModel,
          isExpanded: true,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Select a device',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          icon: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.phone_android, color: Colors.blue),
          ),
          style: Theme.of(context).textTheme.bodyMedium,
          items: _phoneModels.map((model) {
            return DropdownMenuItem(
              value: model,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(model),
              ),
            );
          }).toList(),
          onChanged: (value) async {
            if (value != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('selected_device', value);
              setState(() {
                _selectedPhoneModel = value;
              });
              _fetchStatsData();
            }
          },
        ),
      ),
    );
  }

  // Add null safety to time range selector
  Widget _buildTimeRangeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_timeRanges.length, (index) {
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (mounted) {
                  setState(() => _selectedTimeRange = index);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedTimeRange == index
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _timeRanges[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedTimeRange == index
                        ? const Color(0xFF6C5CE7)
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOverviewTab(BoxConstraints constraints) {
    final isTablet = constraints.maxWidth > 600;
    final padding = constraints.maxWidth * 0.04;

    return ListView(
      padding: EdgeInsets.all(padding),
      children: [
        StatsCard.buildQuickStats(
          context: context,
          callStats: _callStats,
          totalMessagesCount: _totalMessagesCount,
          messageTrend: _messageTrend,
          callTrend: _callTrend,
          showTrendInfo: _showTrendInfo,
          constraints: constraints,
        ),
        SizedBox(height: padding),
        StatsCard.buildScreenTimeCard(_screenTimeData),
        SizedBox(height: padding),
        StatsCard.buildWebVisitsPieChart(
            _webVisitsData, _isLoading), // Changed from Row to vertical layout
        SizedBox(height: padding),
        StatsCard.buildCallsPieChart(
            _callStats), // Changed from Row to vertical layout
        SizedBox(height: padding),
        StatsCard.buildDigitalWellbeingCard(),
        SizedBox(height: padding),
        StatsCard.buildTopAppsCard(),
        SizedBox(height: padding),
        StatsCard.buildLocationTimelineCard(),
      ],
    );
  }

  Widget _buildCommunicationTab(BoxConstraints constraints) {
    final padding = constraints.maxWidth * 0.04;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: constraints.maxWidth - padding * 2,
              child: StatsCard.buildCommunicationStats(),
            ),
            SizedBox(height: padding),
            StatsCard.buildSmsStatsCard(),
            SizedBox(height: padding),
            StatsCard.buildMessagingAppsCard(),
            SizedBox(height: padding),
            StatsCard.buildWebsiteStatsCard(),
            SizedBox(height: padding),
            StatsCard.buildCallHistoryCard(),
            SizedBox(height: padding),
            StatsCard.buildContactsAnalysisCard(),
            SizedBox(height: padding),
          ],
        ),
      ),
    );
  }

  Widget _buildAppStatsTab(BoxConstraints constraints) {
    final padding = constraints.maxWidth * 0.04;

    return ListView(
      padding: EdgeInsets.all(padding),
      children: [
        StatsCard.buildAppUsageSummary(),
        SizedBox(height: padding),
        StatsCard.buildTopAppsUsageChart(),
        SizedBox(height: padding),
        StatsCard.buildAppCategoryBreakdown(),
        SizedBox(height: padding),
        StatsCard.buildDetailedAppList(),
      ],
    );
  }

  Widget _buildTab(IconData icon, String label) {
    return Tab(
      height: 44, // Reduced height
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8), // Reduced padding
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // Center the content
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18), // Reduced icon size
            const SizedBox(width: 4), // Reduced spacing
            Text(label),
          ],
        ),
      ),
    );
  }
}

class CallStats {
  final String type;
  final int count;
  final Duration duration;

  CallStats(this.type, this.count, this.duration);
}

class WebsiteStats {
  final String category;
  final int visits;
  final Duration duration;

  WebsiteStats(this.category, this.visits, this.duration);
}
