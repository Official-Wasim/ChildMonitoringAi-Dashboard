import 'package:flutter/material.dart';
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
import '../services/stats_screen/fetch_stats_data.dart'; 

class AdvancedStatsScreen extends StatefulWidget {
  final String selectedDevice;

  const AdvancedStatsScreen({
    Key? key,
    required this.selectedDevice,
  }) : super(key: key);

  @override
  State<AdvancedStatsScreen> createState() => _AdvancedStatsScreenState();
}

class _AdvancedStatsScreenState extends State<AdvancedStatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  int _totalMessagesCount = 0;
  double _messageTrend = 0;
  double _callTrend = 0;

  List<ChartData> _webVisitsData = [];

  final UserStatsService _statsService = UserStatsService();

  List<ScreenTimeData> _screenTimeData = [];

  // Update these variables
  Map<String, dynamic> _messageStats = {
    'today': 0, 
    'yesterday': 0,
    'trend': 0.0,
  };

  // Add these variables
  int _screenTimeMinutes = 0;
  int _appsUsed = 0;

  // Add these variables
  double _screenTimeTrend = 0.0;
  double _appsUsedTrend = 0.0;

  // Add this variable
  List<Map<String, dynamic>> _topApps = [];

  // Add this variable with the existing state variables
  Map<String, dynamic>? overview;

  List<Map<String, dynamic>> _detailedAppUsage = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData(); // Replace _loadSelectedDevice() with this
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        _userId = user.uid;

        // First try to load from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final savedDevice = prefs.getString('selected_device');

        if (savedDevice != null) {
          setState(() {
            _selectedPhoneModel = savedDevice;
            _phoneModels = [savedDevice]; // Initialize with saved device
          });
          // Fetch data for the saved device
          await _fetchStatsData();
          // Then fetch full device list in background
          _fetchDevices(savedDevice);
        } else {
          // If no saved device, fetch from database
          await _fetchDevices(null);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error initializing data: $e');
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

  Future<void> _fetchDevices(String? currentDevice) async {
    if (_userId == null || !mounted) return;

    try {
      final phonesSnapshot =
          await _databaseRef.child('users/$_userId/phones').get();
      if (phonesSnapshot.exists) {
        final devices = phonesSnapshot.children.map((e) => e.key!).toList();

        if (mounted) {
          setState(() {
            _phoneModels = devices;
            // Only update selected device if none is currently selected
            if (_selectedPhoneModel == null) {
              _selectedPhoneModel = devices.isNotEmpty ? devices.first : null;
            } else if (currentDevice != null &&
                !devices.contains(currentDevice)) {
              // If current device is not in the list, switch to first available
              _selectedPhoneModel = devices.isNotEmpty ? devices.first : null;
            }
          });

          if (_selectedPhoneModel != null && currentDevice == null) {
            _fetchStatsData(); // Only fetch data if no current device
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
      final results = await Future.wait([
        _statsService.fetchTodaysOverview(
            _userId!, _selectedPhoneModel!, DateTime.now()),
        _statsService.fetchStatsData(_userId!, _selectedPhoneModel!),
        _statsService.fetchTopApps(
            _userId!, _selectedPhoneModel!, DateTime.now()),
        _statsService.fetchScreenTimeData(_userId!, _selectedPhoneModel!),
        _statsService.fetchDetailedAppUsage(
            _userId!, _selectedPhoneModel!, DateTime.now()),
      ]);

      if (mounted) {
        setState(() {
          // Store the complete overview data
          overview = results[0] as Map<String, dynamic>;
          _screenTimeMinutes = overview?['screenTime'] ?? 0;
          _screenTimeTrend = overview?['screenTimeTrend'] ?? 0.0;
          _appsUsed = overview?['appsUsed'] ?? 0;
          _appsUsedTrend = overview?['appsUsedTrend'] ?? 0.0;

          final stats = results[1] as Map<String, dynamic>;
          _callStats = stats['callStats'] as Map<String, dynamic>;
          _callDetails =
              List<Map<String, dynamic>>.from(_callStats['details'] ?? []);
          _messageStats = stats['messageStats'] as Map<String, dynamic>;
          _totalMessagesCount = _messageStats['current']['total'] ?? 0;
          _messageTrend = _messageStats['trend'] ?? 0.0;
          _webVisitsData = List<ChartData>.from(stats['webVisits'] ?? []);

          _topApps = List<Map<String, dynamic>>.from(results[2] as List);
          _screenTimeData = (results[3] as List)
              .map((data) => data as ScreenTimeData)
              .toList();

          // Fix the type casting for detailed app usage
          _detailedAppUsage =
              (results[4] as List<Map<String, dynamic>>).toList();
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

    // Special handling for screen time
    if (title == 'Screen Time') {
      int todayMinutes = _screenTimeMinutes;
      int yesterdayMinutes =
          (todayMinutes * 100 / (100 + double.parse(numericValue))).round();

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
                Text('Today: ${_formatScreenTime(todayMinutes)}'),
                Text('Yesterday: ${_formatScreenTime(yesterdayMinutes)}'),
                Text(
                  'Change: $trend',
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
      return;
    }

    // Handle other stats
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

  String _formatScreenTime(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${remainingMinutes}m';
    }
    return '${remainingMinutes}m';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen()),
        );
        return false;
      },
      child: Scaffold(
        extendBodyBehindAppBar: false, // Changed to false
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppTheme.primaryColor,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppTheme.surfaceColor,
              size: 22,
            ),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => DashboardScreen()),
            ),
          ),
          title: const Text(
            "Statistics",
            style: AppTheme.headlineStyle,
          ),
          shape: AppTheme.appBarTheme.shape,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60), // Adjusted height
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
        body: _isLoading
            ? _buildLoadingIndicator()
            : Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.backgroundGradient,
                ),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        children: [
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
                                  _buildTab(
                                      Icons.dashboard_outlined, 'Overview'),
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
                      return RecentsScreen(
                          selectedDevice: widget.selectedDevice);
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
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading statistics...',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BoxConstraints constraints) {
    final isTablet = constraints.maxWidth > 600;
    final padding = constraints.maxWidth * 0.04;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      );
    }

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
          screenTimeMinutes: _screenTimeMinutes, // Add this
          screenTimeTrend: _screenTimeTrend,
          appsUsed: _appsUsed, // Add this
          appsUsedTrend: _appsUsedTrend,
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
        StatsCard.buildTopAppsCard(_topApps),
      ],
    );
  }

  Widget _buildCommunicationTab(BoxConstraints constraints) {
    final padding = constraints.maxWidth * 0.04;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: constraints.maxWidth - padding * 2,
              child: StatsCard.buildCommunicationStats(
                messageCount: _totalMessagesCount,
                callCount: _callStats['totalCalls'] ?? 0,
                contactCount: _callDetails.length,
              ),
            ),
            SizedBox(height: padding),
          ],
        ),
      ),
    );
  }

  Widget _buildAppStatsTab(BoxConstraints constraints) {
    final padding = constraints.maxWidth * 0.04;
    final appOpensCount = (overview?['appOpens'] ?? 0) as int;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(padding),
      children: [
        StatsCard.buildAppUsageSummary(
          appOpens: appOpensCount,
          appsUsed: _appsUsed,
        ),
        SizedBox(height: padding),
        StatsCard.buildTopAppsUsageChart(_topApps), // Pass the real data
        SizedBox(height: padding),
        StatsCard.buildDetailedAppList(_detailedAppUsage), // Update this line
      ],
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
            offset: const Offset(0, 2),
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
          icon: const Padding(
            padding: EdgeInsets.only(right: 16),
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
          onChanged: !_isLoading
              ? (value) async {
                  if (value != null) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('selected_device', value);
                    setState(() {
                      _selectedPhoneModel = value;
                    });
                    _fetchStatsData();
                  }
                }
              : null, // Disable dropdown while loading
        ),
      ),
    );
  }

  Widget _buildTab(IconData icon, String label) {
    return Tab(
      height: 44, // Reduced height
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // Center the content
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 4),
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
