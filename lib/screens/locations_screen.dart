import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:sticky_headers/sticky_headers/widget.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart'; // Add this import
import 'package:shared_preferences/shared_preferences.dart'; // Add this import

class LocationInfo {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;

  LocationInfo({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
  });

  factory LocationInfo.fromFirebase(
      String timestampKey, Map<dynamic, dynamic> data) {
    return LocationInfo(
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      accuracy: (data['accuracy'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(timestampKey)),
    );
  }
}

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  _LocationsScreenState createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  static const String SELECTED_DEVICE_KEY = 'selected_device';
  String _selectedDevice = '';

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<LocationInfo> locationsList = [];
  bool isLoading = true;

  final String uniqueUserId = 'rgNHZYmejJd6D9r5nvyjSKknryA3';
  final String phoneModel = 'sdk_gphone64_x86_64';

  String _searchQuery = ""; // Add search query state
  List<LocationInfo> _filteredLocationsList = []; // Add filtered locations list

  static const int _itemsPerPage = 20;
  int _currentPage = 0;
  bool _hasMoreData = true;

  final RefreshController _refreshController = RefreshController(initialRefresh: false); // Add this line

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
      _fetchLocationsData();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchLocationsData({bool isRefresh = false}) async {
    if (_selectedDevice.isEmpty) return;
    try {
      final DatabaseReference locationRef = _databaseRef
          .child('users')
          .child(uniqueUserId)
          .child('phones')
          .child(_selectedDevice)
          .child('location');

      final DataSnapshot locationsSnapshot = await locationRef.get();

      if (locationsSnapshot.exists && locationsSnapshot.value != null) {
        final Map<dynamic, dynamic> locationsData =
            locationsSnapshot.value as Map<dynamic, dynamic>;

        final List<LocationInfo> fetchedLocations = [];

        // Iterate through date nodes
        locationsData.forEach((dateKey, dateData) {
          if (dateData is Map<dynamic, dynamic>) {
            // Iterate through timestamp nodes within each date
            dateData.forEach((timestampKey, locationData) {
              try {
                if (locationData is Map<dynamic, dynamic>) {
                  final location = LocationInfo.fromFirebase(
                      timestampKey.toString(), locationData);
                  fetchedLocations.add(location);
                }
              } catch (e) {
                debugPrint(
                    'Error parsing location data for timestamp $timestampKey: $e');
              }
            });
          } else {
            // Handle case where the data is directly under the location node
            try {
              if (dateData is Map<dynamic, dynamic>) {
                final location =
                    LocationInfo.fromFirebase(dateKey.toString(), dateData);
                fetchedLocations.add(location);
              }
            } catch (e) {
              debugPrint(
                  'Error parsing location data for timestamp $dateKey: $e');
            }
          }
        });

        // Sort by timestamp descending (newest first)
        fetchedLocations.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        setState(() {
          locationsList = fetchedLocations;
          _filteredLocationsList = fetchedLocations; // Initialize filtered list
          isLoading = false;
        });
      } else {
        setState(() {
          locationsList = [];
          _filteredLocationsList = []; // Initialize filtered list
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching locations data: $e');
      setState(() {
        isLoading = false;
      });
    }
    if (isRefresh) {
      _refreshController.refreshCompleted();
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      isLoading = true;
    });
    await _fetchLocationsData();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredLocationsList = locationsList.where((location) {
        final searchLower = _searchQuery.toLowerCase();
        return location.latitude.toString().contains(searchLower) ||
            location.longitude.toString().contains(searchLower) ||
            location.timestamp.toString().contains(searchLower);
      }).toList();
      _currentPage = 0;
      _hasMoreData = _filteredLocationsList.length > _itemsPerPage;
    });
  }

  List<LocationInfo> get _paginatedList {
    final startIndex = 0;
    final endIndex = (_currentPage + 1) * _itemsPerPage;
    if (startIndex >= _filteredLocationsList.length) return [];
    return _filteredLocationsList.sublist(
        startIndex, endIndex.clamp(0, _filteredLocationsList.length));
  }

  void _loadMoreData() {
    setState(() {
      _currentPage++;
      _hasMoreData =
          (_currentPage + 1) * _itemsPerPage < _filteredLocationsList.length;
    });
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Map<String, List<LocationInfo>> _groupLocationsByDate(
      List<LocationInfo> locations) {
    Map<String, List<LocationInfo>> grouped = {};
    for (var location in locations) {
      final dateStr = DateFormat('dd MMM yyyy').format(location.timestamp);
      grouped.putIfAbsent(dateStr, () => []);
      grouped[dateStr]!.add(location);
    }
    return Map.fromEntries(grouped.entries.toList()
      ..sort((a, b) => DateFormat('dd MMM yyyy')
          .parse(b.key)
          .compareTo(DateFormat('dd MMM yyyy').parse(a.key))));
  }

  Widget _buildLocationsList() {
    final groupedLocations = _groupLocationsByDate(_filteredLocationsList);
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: groupedLocations.length,
      itemBuilder: (context, index) {
        final dateStr = groupedLocations.keys.elementAt(index);
        final locationsForDate = groupedLocations[dateStr]!;

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
                      colors: [
                        Colors.blue,
                        Colors.blue.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 4,
                        offset: Offset(0, 2),
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
                  '${locationsForDate.length} locations',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              children: locationsForDate
                  .map((location) => LocationTile(
                        location: location,
                      ))
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(160),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
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
              "Location History",
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(100),
              child: Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 30,
                  top: 12,
                ),
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
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search locations...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      prefixIcon: Icon(Icons.search, color: Colors.blue), // Change search icon color
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
            ),
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
          child: Column(
            children: [
              const SizedBox(height: 16),
              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredLocationsList.isEmpty
                        ? Center(
                            child: Text(
                              'No location data found matching "$_searchQuery".',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        : SmartRefresher(
                            controller: _refreshController,
                            enablePullDown: true,
                            onRefresh: () => _fetchLocationsData(isRefresh: true),
                            child: _buildLocationsList(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}

class LocationTile extends StatelessWidget {
  final LocationInfo location;

  const LocationTile({
    super.key,
    required this.location,
  });

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
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
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
                    Colors.blue.withOpacity(0.3),
                    Colors.blue.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on,
                color: Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location Update',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: theme.colorScheme.secondary.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(location.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lat: ${location.latitude.toStringAsFixed(6)}\nLon: ${location.longitude.toStringAsFixed(6)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Accuracy: ${location.accuracy.toStringAsFixed(1)} meters',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
