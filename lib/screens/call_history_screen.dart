import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sticky_headers/sticky_headers/widget.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import 'package:pull_to_refresh/pull_to_refresh.dart'; // Add this import
import '../models/call_info.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({Key? key}) : super(key: key);

  @override
  _CallHistoryScreenState createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
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

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<CallInfo> _callList = [];
  List<CallInfo> _filteredCallList = [];
  String _errorMessage = ''; // Add an error message field
  String _searchQuery = ""; // Add search query state
  String _selectedFilter = "all"; // "all", "incoming", "outgoing", "missed"
  bool _isLoading = true; // Add loading state
  static const int _itemsPerPage = 50; // Update to 50 items
  int _currentPage = 0;
  bool _hasMoreData = true;
  static const String SELECTED_DEVICE_KEY =
      'selected_device'; // Add this constant
  String _selectedDevice = ''; // Add this variable
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false); // Add this line

  List<CallInfo> get _paginatedCalls {
    final startIndex = 0;
    final endIndex = (_currentPage + 1) * _itemsPerPage;
    if (startIndex >= _filteredCallList.length) return [];
    return _filteredCallList.sublist(
        startIndex, endIndex.clamp(0, _filteredCallList.length));
  }

  void _loadMoreData() {
    setState(() {
      _currentPage++;
      _hasMoreData =
          (_currentPage + 1) * _itemsPerPage < _filteredCallList.length;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSelectedDevice(); // Add this method call
  }

  // Add this method to load the selected device
  Future<void> _loadSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedDevice = prefs.getString(SELECTED_DEVICE_KEY);
    if (selectedDevice != null) {
      setState(() {
        _selectedDevice = selectedDevice;
      });
      _fetchCallData(); // Move fetchCallData here after device is loaded
    } else {
      setState(() {
        _errorMessage = 'No device selected';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCallData({bool isRefresh = false}) async {
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
        _callList = [];
        _filteredCallList = [];
        _errorMessage = 'User is not logged in'; // Set error message
        _isLoading = false; // Set loading state to false
      });
      return;
    }

    final String uniqueUserId = user.uid;

    try {
      final callSnapshot = await _databaseRef
          .child('users/$uniqueUserId/phones/$_selectedDevice/calls')
          .get();

      if (callSnapshot.exists) {
        final Map<String, dynamic> callsByDate =
            Map<String, dynamic>.from(callSnapshot.value as Map);

        final List<CallInfo> fetchedCalls = [];

        callsByDate.forEach((dateKey, callEntries) {
          final Map<String, dynamic> callEntriesMap =
              Map<String, dynamic>.from(callEntries);

          callEntriesMap.forEach((callKey, callData) {
            final callMap = Map<String, dynamic>.from(callData);
            fetchedCalls.add(CallInfo(
              name:
                  'Unknown (${callMap['number'] ?? 'Unknown'})', // Display number along with contact name
              phoneNumber: callMap['number'] ?? 'Unknown',
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                  callMap['timestamp'] is int
                      ? callMap['timestamp']
                      : int.tryParse(callMap['timestamp'].toString()) ??
                          0), // Ensure timestamp is converted to DateTime
              type: _getCallType(callMap['type']
                  .toString()), // Ensure type is parsed as a string
              duration: Duration(
                  seconds: callMap['duration'] is int
                      ? callMap['duration']
                      : int.tryParse(callMap['duration'].toString()) ??
                          0), // Ensure duration is an integer
              contactName: callMap['contactName'] ?? '', // Add this line
            ));
          });
        });

        fetchedCalls.sort((a, b) => b.timestamp
            .compareTo(a.timestamp)); // Sort by timestamp in descending order

        setState(() {
          _callList = fetchedCalls;
          _filteredCallList = fetchedCalls;
          _errorMessage = ''; // Clear error message
          _isLoading = false; // Set loading state to false
        });
      } else {
        setState(() {
          _callList = [];
          _filteredCallList = [];
          _errorMessage = 'No call data found'; // Set error message
          _isLoading = false; // Set loading state to false
        });
      }
    } catch (e) {
      debugPrint('Error fetching call data: $e');
      setState(() {
        _callList = [];
        _filteredCallList = [];
        _errorMessage = 'Error fetching call data: $e'; // Set error message
        _isLoading = false; // Set loading state to false
      });
    }
    if (isRefresh) {
      _refreshController.refreshCompleted();
    }
  }

  List<CallInfo> _getAllCalls() {
    return _callList;
  }

  DateTime _parseTimestamp(String timestamp) {
    try {
      // If the timestamp is a Unix timestamp (e.g., seconds or milliseconds since epoch)
      if (timestamp.length > 10) {
        final int timestampInMilliseconds = int.parse(timestamp);
        return DateTime.fromMillisecondsSinceEpoch(timestampInMilliseconds);
      } else {
        // Attempt to parse the string as a normal DateTime format
        return DateTime.parse(timestamp);
      }
    } catch (e) {
      debugPrint('Error parsing timestamp: $e');
      return DateTime
          .now(); // Return the current time in case of a parsing error
    }
  }

  CallType _getCallType(String type) {
    switch (type) {
      case '1': // Incoming call
        return CallType.incoming;
      case '2': // Outgoing call
        return CallType.outgoing;
      case '3': // Missed call
        return CallType.missed;
      default:
        return CallType.unknown;
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final calls = _callList;
    setState(() {
      _filteredCallList = calls.where((call) {
        if (_selectedFilter == "incoming") {
          return call.type == CallType.incoming;
        } else if (_selectedFilter == "outgoing") {
          return call.type == CallType.outgoing;
        } else if (_selectedFilter == "missed") {
          return call.type == CallType.missed;
        }
        return true; // Default is "all"
      }).where((call) {
        if (_searchQuery.isEmpty) {
          return true;
        }
        return call.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            call.phoneNumber.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
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
              color: Colors.white,
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
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.filter_list,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      "Filter Calls",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                ...["all", "incoming", "outgoing", "missed"].map((filter) {
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
                                        : filter == "missed"
                                            ? Icons.call_missed
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

  Map<String, List<CallInfo>> _groupCallsByDate(List<CallInfo> calls) {
    Map<String, List<CallInfo>> grouped = {};
    for (var call in calls) {
      final dateStr = DateFormat('dd MMM yyyy').format(call.timestamp);
      grouped.putIfAbsent(dateStr, () => []);
      grouped[dateStr]!.add(call);
    }
    return Map.fromEntries(grouped.entries.toList()
      ..sort((a, b) => DateFormat('dd MMM yyyy')
          .parse(b.key)
          .compareTo(DateFormat('dd MMM yyyy').parse(a.key))));
  }

  Widget _buildCallsList() {
    final groupedCalls = _groupCallsByDate(_paginatedCalls);
    final theme = Theme.of(context);

    return ListView.builder(
      physics: BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: groupedCalls.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= groupedCalls.length) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: TextButton(
                onPressed: _loadMoreData,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: primaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Load More',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        final dateStr = groupedCalls.keys.elementAt(index);
        final callsForDate = groupedCalls[dateStr]!;

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
                        primaryColor,
                        secondaryColor,
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
                  '${callsForDate.length} calls',
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
              children: callsForDate
                  .map((call) => CallHistoryTile(call: call))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

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
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(isSmallScreen ? 30 : 40),
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
              "Call History",
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(isSmallScreen ? 70 : 80),
              child: Container(
                height: isSmallScreen ? 70 : 80,
                padding: EdgeInsets.only(
                  left: isSmallScreen ? 16 : 24,
                  right: isSmallScreen ? 16 : 24,
                  bottom: isSmallScreen ? 16 : 20,
                  top: isSmallScreen ? 8 : 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
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
                            hintText: 'Search calls...',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                            prefixIcon: Icon(Icons.search, color: primaryColor),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
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
                        tooltip: "Filter Calls",
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8EAF6), // Light Indigo 50
              Color(0xFFC5CAE9), // Indigo 100
              Color(0xFFE8EAF6), // Light Indigo 50
            ],
            stops: [0.0, 0.5, 1.0],
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
                    : _filteredCallList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 16 : 24,
                              ),
                              child: Text(
                                _errorMessage.isEmpty
                                    ? _getEmptyStateMessage()
                                    : _errorMessage,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: primaryColor,
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : SmartRefresher(
                            controller: _refreshController,
                            enablePullDown: true,
                            onRefresh: () => _fetchCallData(isRefresh: true),
                            child: _buildCallsList(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getEmptyStateMessage() {
    switch (_selectedFilter) {
      case "incoming":
        return 'No incoming calls found matching "$_searchQuery".';
      case "outgoing":
        return 'No outgoing calls found matching "$_searchQuery".';
      case "missed":
        return 'No missed calls found matching "$_searchQuery".';
      default:
        return 'No calls found matching "$_searchQuery".';
    }
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}

class CallInfo {
  final String name;
  final String phoneNumber;
  final DateTime timestamp;
  final CallType type;
  final Duration? duration;
  final String contactName; // Add this field

  CallInfo({
    required this.name,
    required this.phoneNumber,
    required this.timestamp,
    required this.type,
    this.duration,
    this.contactName = '', // Add default value
  });
}

class CallHistoryTile extends StatelessWidget {
  final CallInfo call;

  const CallHistoryTile({super.key, required this.call});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4), // Added margin
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getCallTypeColor(call.type).withOpacity(0.3),
                    _getCallTypeColor(call.type).withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getCallTypeIcon(call.type),
                color: _getCallTypeColor(call.type),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    call.contactName.isNotEmpty
                        ? '${call.contactName} • ${call.phoneNumber}'
                        : call.phoneNumber,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getCallDirectionIcon(call.type),
                        size: 14,
                        color: theme.colorScheme.secondary.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(call.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  if (call.duration != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDuration(call.duration!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCallTypeColor(CallType type) {
    switch (type) {
      case CallType.missed:
        return Colors.red;
      case CallType.incoming:
        return Colors.green;
      case CallType.outgoing:
        return Colors.blue;
      case CallType.unknown:
        return Colors.grey;
    }
  }

  IconData _getCallTypeIcon(CallType type) {
    switch (type) {
      case CallType.missed:
        return Icons.phone_missed;
      case CallType.incoming:
        return Icons.phone_callback;
      case CallType.outgoing:
        return Icons.phone_forwarded;
      case CallType.unknown:
        return Icons.phone_disabled;
    }
  }

  IconData _getCallDirectionIcon(CallType type) {
    switch (type) {
      case CallType.missed:
        return Icons.call_missed;
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.unknown:
        return Icons.block;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateToCheck == today) {
      return 'Today ${DateFormat('HH:mm').format(dateTime)}';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('yyyy-MM-dd HH:mm')
          .format(dateTime); // Show date and time
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}min ${duration.inSeconds.remainder(60)}s';
    } else {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);
      return '${hours}hr ${minutes}min ${seconds}s';
    }
  }
}

enum CallType { missed, incoming, outgoing, unknown }
