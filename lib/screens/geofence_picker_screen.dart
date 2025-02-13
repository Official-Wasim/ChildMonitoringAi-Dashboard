import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/geocoding_service.dart';
import '../theme/theme.dart';

class GeofenceLocation {
  final String name;
  final double latitude;
  final double longitude;
  final int radius; // Changed from double to int

  GeofenceLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });
}

class GeofencePickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final double initialRadius;

  const GeofencePickerScreen({
    Key? key,
    this.initialLocation,
    this.initialRadius = 100,
  }) : super(key: key);

  @override
  State<GeofencePickerScreen> createState() => _GeofencePickerScreenState();
}

class _GeofencePickerScreenState extends State<GeofencePickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();
  late MapController _mapController;
  LatLng _selectedLocation = const LatLng(0, 0);
  int _radius = 100; // Changed from double to int
  String _selectedAddress = '';
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _radius = widget.initialRadius.toInt(); // Convert to int
    _radiusController.text = _radius.toString();
    _selectedLocation = widget.initialLocation ?? const LatLng(0, 0);

    // If initial location is provided, reverse geocode to get address
    if (widget.initialLocation != null) {
      _reverseGeocode(widget.initialLocation!);
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      final address = await GeocodingService.getAddressFromCoordinates(
        location.latitude,
        location.longitude,
      );
      _safeSetState(() {
        _selectedAddress = address;
        _searchController.text = address;
      });
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      _safeSetState(() => _searchResults = []);
      return;
    }

    _safeSetState(() => _isSearching = true);
    try {
      final results = await GeocodingService.searchLocation(query);
      _safeSetState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Error searching location: $e');
      _safeSetState(() => _isSearching = false);
    }
  }

  void _selectLocation(LatLng location, String address) {
    _safeSetState(() {
      _selectedLocation = location;
      _selectedAddress = address;
      _searchController.text = address;
      _searchResults = [];
    });
    _mapController.move(location, 15);
    if (!_isDragging) {
      _reverseGeocode(location);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _radiusController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.surfaceColor,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Pick Location', style: AppTheme.headlineStyle),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15,
              onTap: (_, location) {
                _selectLocation(location, _selectedAddress);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _selectedLocation,
                    radius: _radius
                        .toDouble(), // Convert back to double for the GeofenceLocation class
                    useRadiusInMeter: true,
                    color: Colors.blue.withOpacity(0.2),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onPanStart: (_) => _isDragging = true,
                      onPanUpdate: (details) {
                        // Convert the drag movement to map coordinates
                        final RenderBox mapBox =
                            context.findRenderObject() as RenderBox;
                        final markerPosition =
                            mapBox.globalToLocal(details.globalPosition);

                        // Convert screen coordinates to map coordinates
                        final newLatLng = _mapController.pointToLatLng(
                          Point(markerPosition.dx, markerPosition.dy),
                        );

                        if (newLatLng != null) {
                          _selectLocation(newLatLng, _selectedAddress);
                        }
                      },
                      onPanEnd: (_) {
                        _isDragging = false;
                        // Update address after marker drag ends
                        _reverseGeocode(_selectedLocation);
                      },
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Search and suggestions wrapper
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Search bar
                Card(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search location',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: _searchLocation,
                  ),
                ),
                // Info text appears only when no search results
                if (_searchResults.isEmpty)
                  Card(
                    color: Colors.white.withOpacity(0.9),
                    margin: const EdgeInsets.only(top: 8),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap anywhere on map or drag the marker to select location',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Search results
                if (_searchResults.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          title: Text(result['name']),
                          subtitle: Text(result['address']),
                          onTap: () {
                            _selectLocation(
                              LatLng(result['lat'], result['lon']),
                              result['address'],
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.radio_button_checked,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Fence Radius (m)',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _radiusController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Enter radius in meters',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _radius = int.tryParse(value) ?? _radius;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(
                      context,
                      GeofenceLocation(
                        name: '',
                        latitude: _selectedLocation.latitude,
                        longitude: _selectedLocation.longitude,
                        radius: _radius, // No need to convert to double anymore
                      ),
                    );
                  },
                  child: const Text(
                    'Confirm Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
