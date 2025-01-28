import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:sticky_headers/sticky_headers/widget.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/geocoding_service.dart';
import '../models/location_info.dart';
import 'map_screen.dart';

// Remove the LocationInfo class definition since we're importing it from models

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  _LocationsScreenState createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  static const String SELECTED_DEVICE_KEY = 'selected_device';
  String _selectedDevice = '';
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<LocationInfo> _locationsList = [];
  List<LocationInfo> _filteredLocationsList = [];
  String _errorMessage = '';
  String _searchQuery = '';
  bool _isLoading = true;
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  int _currentPage = 0;
  final int _itemsPerPage = 20;
  bool _hasMoreData = true;

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
        _errorMessage = 'No device selected';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLocationsData({bool isRefresh = false}) async {
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

    try {
      final locationsSnapshot = await _databaseRef
          .child('users/${user.uid}/phones/$_selectedDevice/location')
          .get();

      if (locationsSnapshot.exists) {
        final Map<dynamic, dynamic> locationData =
            locationsSnapshot.value as Map<dynamic, dynamic>;

        final List<LocationInfo> fetchedLocations = [];

        locationData.forEach((dateKey, dateData) {
          if (dateData is Map) {
            dateData.forEach((timestampKey, locationData) {
              if (locationData is Map) {
                try {
                  // Remove underscore from timestamp key before parsing
                  final cleanTimestamp =
                      timestampKey.toString().replaceFirst('_', '');
                  fetchedLocations.add(LocationInfo(
                    latitude: (locationData['latitude'] as num).toDouble(),
                    longitude: (locationData['longitude'] as num).toDouble(),
                    timestamp: DateTime.fromMillisecondsSinceEpoch(
                        int.parse(cleanTimestamp)),
                    accuracy: (locationData['accuracy'] as num).toDouble(),
                  ));
                } catch (e) {
                  print('Error parsing location data: $e');
                  print('Problematic timestamp key: $timestampKey');
                }
              }
            });
          }
        });

        fetchedLocations.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        setState(() {
          _locationsList = fetchedLocations;
          _filteredLocationsList = fetchedLocations;
          _errorMessage = '';
          _isLoading = false;
        });

        // Start fetching addresses in background without waiting
        if (_locationsList.isNotEmpty) {
          _fetchAddressesProgressively(_locationsList);
        }
      } else {
        setState(() {
          _locationsList = [];
          _filteredLocationsList = [];
          _errorMessage = 'No location data found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching location data: $e';
        _locationsList = [];
        _filteredLocationsList = [];
        _isLoading = false;
      });
    }
    if (isRefresh) {
      _refreshController.refreshCompleted();
    }
  }

  void _fetchAddressesProgressively(List<LocationInfo> locations) async {
    for (var location in locations) {
      if (!mounted) return; // Stop if widget is disposed
      try {
        final address = await GeocodingService.getAddressFromCoordinates(
          location.latitude,
          location.longitude,
        );
        if (mounted) {
          setState(() {
            location.address = address;
          });
        }
      } catch (e) {
        print('Error fetching address: $e');
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterLocations();
    });
  }

  void _filterLocations() {
    setState(() {
      _filteredLocationsList = _locationsList.where((location) {
        if (_searchQuery.isEmpty) return true;
        return location.latitude
                .toString()
                .contains(_searchQuery.toLowerCase()) ||
            location.longitude.toString().contains(_searchQuery.toLowerCase());
      }).toList();
    });
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchLocationsData();
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
    final groupedLocations = _groupLocationsByDate(_paginatedList);
    final theme = Theme.of(context);

    return ListView.builder(
      physics: BouncingScrollPhysics(), // Add bouncy physics
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: groupedLocations.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= groupedLocations.length) {
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }

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
        preferredSize: Size.fromHeight(kToolbarHeight + 60), // Changed from 160
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
              preferredSize: Size.fromHeight(80), // Changed from 100
              child: Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 20, // Changed from 30
                  top: 8, // Changed from 12
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
                      prefixIcon: Icon(Icons.search,
                          color: Colors.blue), // Change search icon color
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
                child: _isLoading
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
                            onRefresh: () =>
                                _fetchLocationsData(isRefresh: true),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.blueAccent.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.05),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MapScreen(location: location),
                  ),
                );
              },
              splashColor: Colors.blueAccent.withOpacity(0.1),
              highlightColor: Colors.blueAccent.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(location.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '±${location.accuracy.toStringAsFixed(1)}m',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (location.address != 'Fetching address...')
                            Text(
                              location.address,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                height: 1.3,
                                fontWeight: FontWeight.w600, // Made bolder
                                fontSize: 13.5, // Slightly larger
                              ),
                              maxLines: 3, // Changed from 2 to 3
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blueAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Fetching address...',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.blueAccent,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.blueAccent.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
