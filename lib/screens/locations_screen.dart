import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchLocationsData();
  }

  Future<void> _fetchLocationsData() async {
    try {
      final DatabaseReference locationRef = _databaseRef
          .child('users')
          .child(uniqueUserId)
          .child('phones')
          .child(phoneModel)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text("Locations"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search locations...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
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
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredLocationsList.isEmpty
                  ? const Center(
                      child: Text(
                        'No location data available.',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Showing ${_paginatedList.length} of ${_filteredLocationsList.length} locations',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              itemCount: _paginatedList.length +
                                  (_hasMoreData ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= _paginatedList.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    child: Center(
                                      child: ElevatedButton(
                                        onPressed: _loadMoreData,
                                        child: const Text('Load More'),
                                      ),
                                    ),
                                  );
                                }
                                final location = _paginatedList[index];
                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.location_on,
                                      size: 50,
                                      color: Colors.blue,
                                    ),
                                    title: Text(
                                      'Lat: ${location.latitude.toStringAsFixed(6)}\n'
                                      'Lon: ${location.longitude.toStringAsFixed(6)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Accuracy: ${location.accuracy.toStringAsFixed(1)} meters',
                                          style: const TextStyle(
                                              color: Colors.black87),
                                        ),
                                        Text(
                                          'Date & Time: ${location.timestamp.day}/${location.timestamp.month}/${location.timestamp.year} ${_formatTime(location.timestamp)}',
                                          style: const TextStyle(
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
