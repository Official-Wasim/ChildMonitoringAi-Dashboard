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
      final specificDate = '2025-01-04';
      final callsSnapshot = await _databaseRef
          .child(
              'users/$_userId/phones/$_selectedPhoneModel/calls/$specificDate')
          .get();

      if (callsSnapshot.exists && mounted) {
        // Count unique call IDs for total calls
        final callsData = Map<String, dynamic>.from(callsSnapshot.value as Map);
        final totalCalls = callsData.length; // This counts unique IDs

        int incoming = 0;
        int outgoing = 0;
        int missed = 0;
        int totalDuration = 0;
        List<Map<String, dynamic>> callDetails = [];

        callsData.forEach((callId, callData) {
          final call = Map<String, dynamic>.from(callData as Map);
          callDetails.add(call);
          switch (call['type']) {
            case 'incoming':
              incoming++;
              totalDuration += (call['duration'] ?? 0) as int;
              break;
            case 'outgoing':
              outgoing++;
              totalDuration += (call['duration'] ?? 0) as int;
              break;
            case 'missed':
              missed++;
              break;
          }
        });

        debugPrint('Total unique calls: $totalCalls');
        debugPrint('Fetched calls: $callDetails');

        setState(() {
          _callStats = {
            'incoming': incoming,
            'outgoing': outgoing,
            'missed': missed,
            'totalDuration': totalDuration,
            'totalCalls': totalCalls, // Add total calls count
          };
          _callDetails = callDetails;
        });
      } else {
        setState(() {
          _callStats = {
            'incoming': 0,
            'outgoing': 0,
            'missed': 0,
            'totalDuration': 0,
            'totalCalls': 0,
          };
          _callDetails = [];
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Statistics",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(40), // Keep bottom corners rounded
          ),
        ),
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.withOpacity(0.1),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTimeRangeSelector(),
                    ],
                  ),
                ),
              ),
            ],
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
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
                        isScrollable: true, // Make the TabBar scrollable
                        indicator: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        dividerColor: Colors.transparent,
                        labelColor: Colors.blue,
                        unselectedLabelColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        tabs: [
                          _buildTab(Icons.dashboard_outlined, 'Overview'),
                          _buildTab(Icons.message_outlined, 'Communication'),
                          _buildTab(Icons.apps_outlined, 'App Stats'),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: MediaQuery.of(context).size.height -
                        200, // Adjust height
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildCommunicationTab(),
                        _buildAppStatsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        key: _bottomNavigationKey,
        index: _page,
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
        backgroundColor: Colors.blueAccent,
        animationCurve: Curves.easeInOutCubic,
        animationDuration: const Duration(milliseconds: 800),
        onTap: (index) {
          setState(() {
            _page = index;
          });
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
                } else if (index == 4) {
                  return SettingsScreen();
                } else {
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

  Widget _buildTimeRangeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_timeRanges.length, (index) {
          return GestureDetector(
            onTap: () => setState(() => _selectedTimeRange = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedTimeRange == index
                    ? Colors.white
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _timeRanges[index],
                style: TextStyle(
                  color: _selectedTimeRange == index
                      ? const Color(0xFF6C5CE7)
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildQuickStats(),
        const SizedBox(height: 20),
        _buildScreenTimeCard(),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildWebVisitsPieChart()),
            const SizedBox(width: 16),
            Expanded(child: _buildCallsPieChart()),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildSmsPieChart()),
            const SizedBox(width: 16),
            Expanded(child: _buildAppUsageChart()),
          ],
        ),
        const SizedBox(height: 20),
        _buildDetailedCallStatsCard(),
        const SizedBox(height: 20),
        _buildTopAppsCard(),
        const SizedBox(height: 20),
        _buildLocationTimelineCard(),
      ],
    );
  }

  Widget _buildChartLegendItem(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('${value.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildWebVisitsPieChart() {
    final List<ChartData> webData = [
      ChartData('Google', 35),
      ChartData('Youtube', 28),
      ChartData('Facebook', 20),
      ChartData('Others', 17),
    ];

    final List<Color> colors = [
      const Color(0xFF6C5CE7),
      const Color(0xFF81ECEC),
      const Color(0xFFFFA502),
      const Color(0xFFFF4757),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Web Visits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: SfCircularChart(
                series: <CircularSeries>[
                  PieSeries<ChartData, String>(
                    dataSource: webData,
                    xValueMapper: (ChartData data, _) => data.category,
                    yValueMapper: (ChartData data, _) => data.value,
                    pointColorMapper: (ChartData data, index) =>
                        colors[index ?? 0],
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              webData.length,
              (index) => _buildChartLegendItem(
                webData[index].category,
                webData[index].value,
                colors[index],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallsPieChart() {
    final List<ChartData> callData = [
      ChartData('John', 45),
      ChartData('Alice', 30),
      ChartData('Bob', 15),
      ChartData('Others', 10),
    ];

    final List<Color> colors = [
      const Color(0xFF6C5CE7),
      const Color(0xFF81ECEC),
      const Color(0xFFFFA502),
      const Color(0xFFFF4757),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Call Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: SfCircularChart(
                series: <CircularSeries>[
                  PieSeries<ChartData, String>(
                    dataSource: callData,
                    xValueMapper: (ChartData data, _) => data.category,
                    yValueMapper: (ChartData data, _) => data.value,
                    pointColorMapper: (ChartData data, index) =>
                        colors[index ?? 0],
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              callData.length,
              (index) => _buildChartLegendItem(
                callData[index].category,
                callData[index].value,
                colors[index],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsPieChart() {
    final List<ChartData> smsData = [
      ChartData('Family', 40),
      ChartData('Friends', 35),
      ChartData('Work', 15),
      ChartData('Others', 10),
    ];

    final List<Color> colors = [
      const Color(0xFF6C5CE7),
      const Color(0xFF81ECEC),
      const Color(0xFFFFA502),
      const Color(0xFFFF4757),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SMS Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: SfCircularChart(
                series: <CircularSeries>[
                  PieSeries<ChartData, String>(
                    dataSource: smsData,
                    xValueMapper: (ChartData data, _) => data.category,
                    yValueMapper: (ChartData data, _) => data.value,
                    pointColorMapper: (ChartData data, index) =>
                        colors[index ?? 0],
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              smsData.length,
              (index) => _buildChartLegendItem(
                smsData[index].category,
                smsData[index].value,
                colors[index],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppUsageChart() {
    final List<ChartData> appData = [
      ChartData('Social', 35),
      ChartData('Games', 25),
      ChartData('Education', 20),
      ChartData('Others', 20),
    ];

    final List<Color> colors = [
      const Color(0xFF6C5CE7),
      const Color(0xFF81ECEC),
      const Color(0xFFFFA502),
      const Color(0xFFFF4757),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App Usage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: SfCircularChart(
                series: <CircularSeries>[
                  PieSeries<ChartData, String>(
                    dataSource: appData,
                    xValueMapper: (ChartData data, _) => data.category,
                    yValueMapper: (ChartData data, _) => data.value,
                    pointColorMapper: (ChartData data, index) =>
                        colors[index ?? 0],
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              appData.length,
              (index) => _buildChartLegendItem(
                appData[index].category,
                appData[index].value,
                colors[index],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunicationTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width - 16,
              child: _buildCommunicationStats(),
            ),
            const SizedBox(height: 16),
            _buildSmsStatsCard(),
            const SizedBox(height: 16),
            _buildMessagingAppsCard(),
            const SizedBox(height: 16),
            _buildWebsiteStatsCard(),
            const SizedBox(height: 16),
            _buildCallHistoryCard(),
            const SizedBox(height: 16),
            _buildContactsAnalysisCard(),
            // Add bottom padding for safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SMS Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Add your content here
            const Text('Content for SMS Statistics Card'),
          ],
        ),
      ),
    );
  }

  Widget _buildAppStatsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAppUsageSummary(),
        const SizedBox(height: 20),
        _buildTopAppsUsageChart(),
        const SizedBox(height: 20),
        _buildAppCategoryBreakdown(),
        const SizedBox(height: 20),
        _buildDetailedAppList(),
      ],
    );
  }

  Widget _buildAppUsageSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App Usage Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAppMetric(
                  icon: Icons.access_time,
                  label: 'Total Time',
                  value: '6h 30m',
                  color: const Color(0xFF6C5CE7),
                ),
                _buildAppMetric(
                  icon: Icons.apps,
                  label: 'Apps Used',
                  value: '12',
                  color: const Color(0xFF81ECEC),
                ),
                _buildAppMetric(
                  icon: Icons.launch,
                  label: 'App Opens',
                  value: '85',
                  color: const Color(0xFFFFA502),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppsUsageChart() {
    final List<AppUsageData> topApps = [
      AppUsageData('WhatsApp', 120),
      AppUsageData('YouTube', 90),
      AppUsageData('Chrome', 60),
      AppUsageData('Instagram', 45),
      AppUsageData('Gmail', 30),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Apps by Usage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...topApps.map((app) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(app.category),
                          Text('${app.percentage} min'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: app.percentage / 120,
                        backgroundColor:
                            const Color(0xFF6C5CE7).withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF6C5CE7)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildAppCategoryBreakdown() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildCategoryItem('Social', '2h 15m', 0.4),
            _buildCategoryItem('Entertainment', '1h 45m', 0.3),
            _buildCategoryItem('Productivity', '1h 20m', 0.2),
            _buildCategoryItem('Others', '50m', 0.1),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedAppList() {
    final List<Map<String, dynamic>> apps = [
      {
        'name': 'WhatsApp',
        'category': 'Social',
        'time': '1h 30m',
        'opens': 25,
        'icon': Icons.chat
      },
      {
        'name': 'YouTube',
        'category': 'Entertainment',
        'time': '1h 15m',
        'opens': 12,
        'icon': Icons.play_circle
      },
      {
        'name': 'Chrome',
        'category': 'Productivity',
        'time': '45m',
        'opens': 18,
        'icon': Icons.web
      },
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detailed App Usage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...apps.map((app) => ListTile(
                  leading:
                      Icon(app['icon'] as IconData, color: Color(0xFF6C5CE7)),
                  title: Text(app['name'] as String),
                  subtitle: Text(app['category'] as String),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(app['time'] as String),
                      Text('${app['opens']} opens',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String category, String time, double percentage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category),
              Text(time),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: const Color(0xFF6C5CE7).withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
          ),
        ],
      ),
    );
  }

  Widget _buildAppMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildQuickStats() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          title: 'Total Screen Time',
          value: '4h 23m',
          icon: Icons.timer,
          color: const Color(0xFF6C5CE7),
          trend: '+15%',
        ),
        _buildStatCard(
          title: 'Messages',
          value: '147',
          icon: Icons.message,
          color: const Color(0xFF81ECEC),
          trend: '-3%',
        ),
        _buildStatCard(
          title: 'Calls',
          value: '${_callStats['totalCalls'] ?? 0}', // Use total calls count
          icon: Icons.phone,
          color: const Color(0xFFFFA502),
          trend: '+5%',
        ),
        _buildStatCard(
          title: 'Apps Used',
          value: '8',
          icon: Icons.apps,
          color: const Color(0xFFFF4757),
          trend: '0%',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trend.startsWith('+')
                      ? Colors.green.withOpacity(0.1)
                      : trend.startsWith('-')
                          ? Colors.red.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    color: trend.startsWith('+')
                        ? Colors.green
                        : trend.startsWith('-')
                            ? Colors.red
                            : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenTimeCard() {
    final List<ScreenTimeData> data = [
      ScreenTimeData('Mon', 3),
      ScreenTimeData('Tue', 4),
      ScreenTimeData('Wed', 3.5),
      ScreenTimeData('Thu', 5),
      ScreenTimeData('Fri', 4),
      ScreenTimeData('Sat', 6),
      ScreenTimeData('Sun', 5),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Screen Time Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                ),
                primaryYAxis: NumericAxis(
                  minimum: 0,
                  maximum: 8,
                  interval: 2,
                  majorGridLines: const MajorGridLines(width: 0),
                ),
                plotAreaBorderWidth: 0,
                series: <ChartSeries<ScreenTimeData, String>>[
                  SplineAreaSeries<ScreenTimeData, String>(
                    dataSource: data,
                    xValueMapper: (ScreenTimeData data, _) => data.day,
                    yValueMapper: (ScreenTimeData data, _) => data.hours,
                    color: const Color(0xFF6C5CE7).withOpacity(0.2),
                    borderColor: const Color(0xFF6C5CE7),
                    borderWidth: 3,
                    splineType: SplineType.natural,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDigitalWellbeingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Digital Wellbeing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Add your content here
            const Text('Content for Digital Wellbeing Card'),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Apps Used',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Add your content here
            const Text('Content for Top Apps Used Card'),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsAnalysisCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contacts Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Add your content here
            const Text('Content for Contacts Analysis Card'),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTimelineCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location Timeline',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ...List.generate(
                    3,
                    (index) => ListTile(
                          leading: const Icon(Icons.location_on,
                              color: Color(0xFF6C5CE7)),
                          title: Text('Location ${index + 1}'),
                          subtitle:
                              Text('${DateFormat.jm().format(DateTime.now())}'),
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunicationStats() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Communication Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCommunicationMetric(
                  icon: Icons.message,
                  label: 'Messages',
                  value: '147',
                  color: Color(0xFF6C5CE7),
                ),
                _buildCommunicationMetric(
                  icon: Icons.call,
                  label: 'Calls',
                  value: '23',
                  color: Color(0xFF81ECEC),
                ),
                _buildCommunicationMetric(
                  icon: Icons.people,
                  label: 'Contacts',
                  value: '48',
                  color: Color(0xFFFFA502),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunicationMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildMessagingAppsCard() {
    final List<Map<String, dynamic>> apps = [
      {'name': 'WhatsApp', 'messages': 45, 'icon': Icons.chat},
      {'name': 'SMS', 'messages': 12, 'icon': Icons.sms},
      {'name': 'Messenger', 'messages': 28, 'icon': Icons.messenger},
    ];

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Messaging Apps',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...apps.map((app) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(app['icon'] as IconData,
                          color: Color(0xFF6C5CE7), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          app['name'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${app['messages']} msgs',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCallHistoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Calls',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ...List.generate(
                    3,
                    (index) => ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF6C5CE7),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text('Contact ${index + 1}'),
                          subtitle: Text(DateFormat('MMM d, h:mm a')
                              .format(DateTime.now())),
                          trailing:
                              const Icon(Icons.phone_missed, color: Colors.red),
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebHistoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Web Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ...List.generate(
                    3,
                    (index) => ListTile(
                          leading:
                              const Icon(Icons.web, color: Color(0xFF6C5CE7)),
                          title: Text('Website ${index + 1}'),
                          subtitle: Text(
                              'Visited ${DateFormat.jm().format(DateTime.now())}'),
                          trailing: Text('${(index + 1) * 5} min'),
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstantMessagingStats() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Messaging Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildMessagingMetric('Messages Sent', 78, Icons.send),
            const SizedBox(height: 12),
            _buildMessagingMetric('Messages Received', 92, Icons.message),
            const SizedBox(height: 12),
            _buildMessagingMetric('Active Chats', 12, Icons.chat),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagingMetric(String label, int value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C5CE7).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF6C5CE7)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            Text('$value',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailedCallStatsCard() {
    final List<CallStats> callStats = [
      CallStats('Incoming', _callStats['incoming'],
          Duration(minutes: _callStats['totalDuration'] ~/ 60)),
      CallStats('Outgoing', _callStats['outgoing'],
          Duration(minutes: _callStats['totalDuration'] ~/ 60)),
      CallStats('Missed', _callStats['missed'], const Duration(minutes: 0)),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Call Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ...callStats.map((stat) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              stat.type == 'Incoming'
                                  ? Icons.call_received
                                  : stat.type == 'Outgoing'
                                      ? Icons.call_made
                                      : Icons.call_missed,
                              color: stat.type == 'Missed'
                                  ? Colors.red
                                  : const Color(0xFF6C5CE7),
                            ),
                            const SizedBox(width: 8),
                            Text(stat.type),
                          ],
                        ),
                        Text(
                            '${stat.count} calls (${stat.duration.inMinutes}m)'),
                      ],
                    ),
                  )),
            const SizedBox(height: 20),
            const Text(
              'Call Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ..._callDetails.map((call) => ListTile(
                  leading: Icon(
                    call['type'] == 'incoming'
                        ? Icons.call_received
                        : call['type'] == 'outgoing'
                            ? Icons.call_made
                            : Icons.call_missed,
                    color: call['type'] == 'missed' ? Colors.red : Colors.green,
                  ),
                  title: Text(call['contact'] ?? 'Unknown'),
                  subtitle: Text(
                      'Duration: ${call['duration'] ?? 0} seconds\nTime: ${call['time'] ?? 'Unknown'}'),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildWebsiteStatsCard() {
    final List<WebsiteStats> websiteStats = [
      WebsiteStats('Educational', 45, const Duration(minutes: 120)),
      WebsiteStats('Social Media', 32, const Duration(minutes: 85)),
      WebsiteStats('Entertainment', 28, const Duration(minutes: 60)),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Website Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...websiteStats.map((stat) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(stat.category,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${stat.visits} visits'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: stat.duration.inMinutes / 120, // Max 2 hours
                        backgroundColor:
                            const Color(0xFF6C5CE7).withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF6C5CE7)),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('${stat.duration.inMinutes} mins'),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(IconData icon, String label) {
    return Tab(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class ScreenTimeData {
  final String day;
  final double hours;

  ScreenTimeData(this.day, this.hours);
}

class AppUsageData {
  final String category;
  final double percentage;

  AppUsageData(this.category, this.percentage);
}

class ContactInteraction {
  final String name;
  final int sent;
  final int received;

  ContactInteraction(this.name, this.sent, this.received);
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

class ChartData {
  final String category;
  final double value;

  ChartData(this.category, this.value);
}
