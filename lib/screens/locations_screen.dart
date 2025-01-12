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

  // Hardcoded values for userId and phoneModel
  final String uniqueUserId =
      'rgNHZYmejJd6D9r5nvyjSKknryA3'; // Replace with dynamic user ID
  final String phoneModel =
      'sdk_gphone64_x86_64'; // Replace with dynamic phone model

  @override
  void initState() {
    super.initState();
    _fetchLocationsData();
  }

  // Fetch the location data from Firebase
  Future<void> _fetchLocationsData() async {
    try {
      final locationsSnapshot = await _databaseRef
          .child('users/$uniqueUserId/phones/$phoneModel/location')
          .get();

      if (locationsSnapshot.exists) {
        final Map<String, dynamic> locationsData =
            Map<String, dynamic>.from(locationsSnapshot.value as Map);

        final List<LocationInfo> fetchedLocations = [];

        // Loop through the keys (e.g., 2024-12-19, 2024-12-22)
        for (var dateKey in locationsData.keys) {
          final locationDetails =
              Map<String, dynamic>.from(locationsData[dateKey]);

          // Extract the location details
          final latitude =
              (locationDetails['latitude'] as num?)?.toDouble() ?? 0.0;
          final longitude =
              (locationDetails['longitude'] as num?)?.toDouble() ?? 0.0;
          final accuracy =
              (locationDetails['accuracy'] as num?)?.toDouble() ?? 0.0;
          final timestampStr = locationDetails['timestamp'] as String?;

          // Convert timestamp string to DateTime
          DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(
              int.tryParse(timestampStr ?? '0') ?? 0);

          // Create a LocationInfo object and add it to the list
          fetchedLocations.add(LocationInfo(
            latitude: latitude,
            longitude: longitude,
            timestamp: timestamp,
            accuracy: accuracy,
          ));
        }

        // Sort the list to show the latest location first
        fetchedLocations.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        setState(() {
          locationsList = fetchedLocations;
          isLoading = false;
        });
      } else {
        debugPrint('No location data found.');
        setState(() {
          locationsList = [];
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

  // Function to refresh the data on pull-to-refresh
  Future<void> _onRefresh() async {
    setState(() {
      isLoading = true;
    });
    await _fetchLocationsData(); // Fetch data again
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar:
          true, // Ensures gradient background extends under the AppBar
      appBar: AppBar(
        title: const Text('Locations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(); // Navigate back to the previous screen
          },
        ),
        backgroundColor: Colors.transparent, // Makes AppBar transparent
        elevation: 0, // Removes shadow of the AppBar
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
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : locationsList.isEmpty
                  ? const Center(
                      child: Text(
                        'No location data available.',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _onRefresh, // Trigger refresh on pull
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: locationsList.length,
                        itemBuilder: (context, index) {
                          final location = locationsList[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                              leading: const Icon(
                                Icons.location_on,
                                size: 50,
                                color: Colors.blue,
                              ),
                              title: Text(
                                'Lat: ${location.latitude != 0.0 ? location.latitude.toStringAsFixed(6) : "Unknown"}, '
                                'Lon: ${location.longitude != 0.0 ? location.longitude.toStringAsFixed(6) : "Unknown"}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    location.accuracy != 0.0
                                        ? 'Accuracy: ${location.accuracy} meters'
                                        : 'Accuracy not available',
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                  Text(
                                    'Date: ${location.timestamp.day}/${location.timestamp.month}/${location.timestamp.year}\n'
                                    'Time: ${location.timestamp.hour}:${location.timestamp.minute}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}
