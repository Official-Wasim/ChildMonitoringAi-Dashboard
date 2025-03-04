import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sticky_headers/sticky_headers/widget.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sms_info.dart';

class SmsHistoryScreen extends StatefulWidget {
  const SmsHistoryScreen({Key? key}) : super(key: key);

  @override
  _SmsHistoryScreenState createState() => _SmsHistoryScreenState();
}

class _SmsHistoryScreenState extends State<SmsHistoryScreen> {
  static const String SELECTED_DEVICE_KEY = 'selected_device';
  String _selectedDevice = '';
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<SmsInfo> _smsList = [];
  List<SmsInfo> _filteredSmsList = [];
  String _errorMessage = '';
  String _searchQuery = "";
  String _selectedFilter = "all";
  bool _isLoading = true;
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  static const int _itemsPerPage = 20;
  int _currentPage = 0;
  bool _hasMoreData = true;

  // Add color scheme constants
  static const Color primaryColor = Color(0xFF1A237E); // Deep Indigo
  static const Color secondaryColor =
      Color(0xFF283593); // Slightly lighter Indigo
  static const Color accentColor = Color(0xFF3949AB); // Bright Indigo
  static const Color backgroundColor =
      Color(0xFFF8F9FF); // Light blue-tinted white
  static const Color backgroundGradientStart = Color(0xFFFFFFFF); // Pure white
  static const Color backgroundGradientEnd =
      Color(0xFFF0F2FF); // Very light indigo
  static const Color surfaceColor = Colors.white;

  List<SmsInfo> get _paginatedList {
    final startIndex = 0;
    final endIndex = (_currentPage + 1) * _itemsPerPage;
    if (startIndex >= _filteredSmsList.length) return [];
    return _filteredSmsList.sublist(
        startIndex, endIndex.clamp(0, _filteredSmsList.length));
  }

  void _loadMoreData() {
    setState(() {
      _currentPage++;
      _hasMoreData =
          (_currentPage + 1) * _itemsPerPage < _filteredSmsList.length;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSelectedDevice();
  }

  Future<void> _loadSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedDevice = prefs.getString(SELECTED_DEVICE_KEY);
    if (selectedDevice != null) {
      setState(() {
        _selectedDevice = selectedDevice;
      });
      _fetchSmsData();
    } else {
      setState(() {
        _errorMessage = 'No device selected';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSmsData({bool isRefresh = false}) async {
    if (_selectedDevice.isEmpty) {
      setState(() {
        _errorMessage = 'No device selected';
        _isLoading = false;
      });
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'User is not logged in';
        _isLoading = false;
      });
      return;
    }

    final String uniqueUserId = user.uid;

    try {
      final smsSnapshot = await _databaseRef
          .child('users/$uniqueUserId/phones/$_selectedDevice/sms')
          .get();

      if (smsSnapshot.exists) {
        final Map<String, dynamic> smsByDate =
            Map<String, dynamic>.from(smsSnapshot.value as Map);

        final List<SmsInfo> fetchedSms = [];

        smsByDate.forEach((dateKey, sms) {
          final Map<String, dynamic> smsEntries =
              Map<String, dynamic>.from(sms);

          smsEntries.forEach((key, value) {
            final smsData = Map<String, dynamic>.from(value);
            fetchedSms.add(SmsInfo(
              date: smsData['date'] ?? 'Unknown',
              address: smsData['address'] ?? 'Unknown',
              body: smsData['body'] ?? 'No message',
              timestamp: smsData['timestamp'] is int
                  ? smsData['timestamp']
                  : int.tryParse(smsData['timestamp'].toString()) ?? 0,
              type: smsData['type'] is int
                  ? smsData['type']
                  : int.tryParse(smsData['type'].toString()) ?? 1,
              contactName: smsData['contactName'] ?? '', // Add this line
            ));
          });
        });

        fetchedSms.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        setState(() {
          _smsList = fetchedSms;
          _filteredSmsList = fetchedSms;
          _errorMessage = '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _smsList = [];
          _filteredSmsList = [];
          _errorMessage = 'No SMS data found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching SMS data: $e';
        _smsList = [];
        _filteredSmsList = [];
        _isLoading = false;
      });
    }
    if (isRefresh) {
      _refreshController.refreshCompleted();
    }
  }

  Future<void> _refreshSmsData() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchSmsData();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final sms = _smsList;
    setState(() {
      _filteredSmsList = sms.where((sms) {
        if (_selectedFilter == "incoming") {
          return sms.type == 1;
        } else if (_selectedFilter == "outgoing") {
          return sms.type == 2;
        }
        return true;
      }).where((sms) {
        if (_searchQuery.isEmpty) {
          return true;
        }
        return sms.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            sms.body.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
      _currentPage = 0;
      _hasMoreData = _filteredSmsList.length > _itemsPerPage;
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 340,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFF5F6FF), // Very light indigo
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.15),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.filter_list,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      "Filter Messages",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                ...["all", "incoming", "outgoing"].map((filter) {
                  String title = filter[0].toUpperCase() + filter.substring(1);
                  if (filter == "all") title = "Show All";
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _selectedFilter = filter;
                            _applyFilters();
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedFilter == filter
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedFilter == filter
                                  ? Colors.blue
                                  : Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                filter == "incoming"
                                    ? Icons.call_received
                                    : filter == "outgoing"
                                        ? Icons.call_made
                                        : Icons.all_inclusive,
                                color: _selectedFilter == filter
                                    ? Colors.blue
                                    : Colors.grey,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                title,
                                style: TextStyle(
                                  color: _selectedFilter == filter
                                      ? Colors.blue
                                      : Colors.black87,
                                  fontWeight: _selectedFilter == filter
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              Spacer(),
                              if (_selectedFilter == filter)
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
                SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getFormattedDate(int timestamp) {
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final DateTime now = DateTime.now();

    if (_isToday(dateTime, now)) {
      return 'Today ${DateFormat('HH:mm').format(dateTime)}';
    } else if (_isYesterday(dateTime, now)) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    }
  }

  bool _isToday(DateTime dateTime, DateTime now) {
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  bool _isYesterday(DateTime dateTime, DateTime now) {
    final yesterday = now.subtract(const Duration(days: 1));
    return dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day;
  }

  Map<String, List<SmsInfo>> _groupSmsByDate(List<SmsInfo> messages) {
    Map<String, List<SmsInfo>> grouped = {};
    for (var message in messages) {
      final dateStr = DateFormat('dd MMM yyyy')
          .format(DateTime.fromMillisecondsSinceEpoch(message.timestamp));
      grouped.putIfAbsent(dateStr, () => []);
      grouped[dateStr]!.add(message);
    }
    return Map.fromEntries(grouped.entries.toList()
      ..sort((a, b) => DateFormat('dd MMM yyyy')
          .parse(b.key)
          .compareTo(DateFormat('dd MMM yyyy').parse(a.key))));
  }

  // Add this method to determine if we're on a small screen
  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  // Add this method to get adaptive padding
  EdgeInsets _getAdaptivePadding(BuildContext context) {
    final isSmall = _isSmallScreen(context);
    return EdgeInsets.symmetric(
      horizontal: isSmall ? 16.0 : 24.0,
      vertical: isSmall ? 8.0 : 16.0,
    );
  }

  Widget _buildSmsList() {
    final groupedMessages = _groupSmsByDate(_paginatedList);
    final theme = Theme.of(context);

    return ListView.builder(
      physics: BouncingScrollPhysics(), // Add bouncy physics
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: groupedMessages.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= groupedMessages.length) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: TextButton(
                onPressed: _loadMoreData,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Load More',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        final dateStr = groupedMessages.keys.elementAt(index);
        final messagesForDate = groupedMessages[dateStr]!;

        return StickyHeader(
          header: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor, // Deep Indigo
                        secondaryColor, // Slightly lighter Indigo
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    dateStr,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${messagesForDate.length} messages',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: primaryColor.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              children: messagesForDate
                  .map((sms) => SmsHistoryTile(
                        sms: sms,
                        formattedDate: _getFormattedDate(sms.timestamp),
                      ))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = _isSmallScreen(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize:
            Size.fromHeight(kToolbarHeight + (isSmallScreen ? 60 : 80)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, secondaryColor],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(isSmallScreen ? 30 : 40),
              bottomRight: Radius.circular(isSmallScreen ? 30 : 40),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              "SMS History",
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(isSmallScreen ? 70 : 80),
              child: Container(
                height: isSmallScreen ? 70 : 80, // Add explicit height
                padding: EdgeInsets.only(
                  left: isSmallScreen ? 16 : 24,
                  right: isSmallScreen ? 16 : 24,
                  bottom: isSmallScreen ? 16 : 20,
                  top: isSmallScreen ? 8 : 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SizedBox(
                            // Wrap with SizedBox for explicit constraints
                            height: constraints.maxHeight,
                            child: Container(
                              width: constraints.maxWidth,
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
                              child: TextField(
                                onChanged: _onSearchChanged,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search SMS...',
                                  hintStyle:
                                      theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                  prefixIcon:
                                      Icon(Icons.search, color: primaryColor),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.filter_list, color: Colors.white),
                        onPressed: _showFilterDialog,
                        tooltip: "Filter SMS",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8EAF6), // Light Indigo 50
              Color(0xFFC5CAE9), // Indigo 100
              Color(0xFFE8EAF6), // Light Indigo 50
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : _filteredSmsList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: _getAdaptivePadding(context),
                              child: Text(
                                _errorMessage.isEmpty
                                    ? _selectedFilter == "incoming"
                                        ? 'No incoming SMS found matching "$_searchQuery".'
                                        : _selectedFilter == "outgoing"
                                            ? 'No outgoing SMS found matching "$_searchQuery".'
                                            : 'No SMS found matching "$_searchQuery".'
                                    : _errorMessage,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: primaryColor,
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              return SmartRefresher(
                                controller: _refreshController,
                                enablePullDown: true,
                                onRefresh: () => _fetchSmsData(isRefresh: true),
                                child: _buildResponsiveSmsList(constraints),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveSmsList(BoxConstraints constraints) {
    final isWideScreen = constraints.maxWidth > 900;
    final groupedMessages = _groupSmsByDate(_paginatedList);

    if (isWideScreen) {
      // Grid layout for wider screens
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        padding: EdgeInsets.all(16),
        itemCount: _paginatedList.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _paginatedList.length) {
            return Center(
              child: TextButton(
                onPressed: _loadMoreData,
                child: Text('Load More'),
              ),
            );
          }
          return SmsHistoryTile(
            sms: _paginatedList[index],
            formattedDate: _getFormattedDate(_paginatedList[index].timestamp),
          );
        },
      );
    } else {
      // Original list layout for smaller screens
      return _buildSmsList();
    }
  }
}

class SmsHistoryTile extends StatelessWidget {
  final SmsInfo sms;
  final String formattedDate;

  const SmsHistoryTile({
    super.key,
    required this.sms,
    required this.formattedDate,
  });

  void _showMessageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: BoxConstraints(maxWidth: 400),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (sms.type == 2 ? Colors.blue : Colors.green)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      sms.type == 2 ? Icons.send : Icons.inbox,
                      color: sms.type == 2 ? Colors.blue : Colors.green,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sms.address,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    sms.type == 2 ? Icons.arrow_outward : Icons.arrow_downward,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withOpacity(0.7),
                  ),
                  SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.7),
                        ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: SingleChildScrollView(
                  child: Text(
                    sms.body,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return GestureDetector(
      onTap: () => _showMessageDialog(context),
      child: Container(
        margin: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 4 : 6,
          horizontal: isSmallScreen ? 0 : 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.white.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Row(
            children: [
              Container(
                width: isSmallScreen ? 44 : 52,
                height: isSmallScreen ? 44 : 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      sms.type == 2
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.green.withOpacity(0.3),
                      sms.type == 2
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  sms.type == 2 ? Icons.send : Icons.inbox,
                  color: sms.type == 2 ? Colors.blue : Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sms.contactName.isNotEmpty
                          ? '${sms.contactName} • ${sms.address}'
                          : sms.address,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          sms.type == 2
                              ? Icons.arrow_outward
                              : Icons.arrow_downward,
                          size: 14,
                          color: theme.colorScheme.secondary.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.secondary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sms.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
