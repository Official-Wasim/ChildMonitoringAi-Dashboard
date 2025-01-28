import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_info.dart';

class MapScreen extends StatefulWidget {
  // Changed to StatefulWidget
  final LocationInfo location;

  const MapScreen({
    Key? key,
    required this.location,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _isSatelliteView = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Location Map',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          // Add satellite toggle button
          IconButton(
            icon: Icon(
              _isSatelliteView ? Icons.map : Icons.satellite,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isSatelliteView = !_isSatelliteView;
              });
            },
            tooltip: _isSatelliteView
                ? 'Switch to Map View'
                : 'Switch to Satellite View',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter:
                  LatLng(widget.location.latitude, widget.location.longitude),
              initialZoom: 16.0,
              backgroundColor: Colors.grey[300] ?? Colors.grey,
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatelliteView
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
                tileProvider: NetworkTileProvider(
                  headers: {
                    'User-Agent':
                        'Child Monitoring Ai/1.0', // Replace with your app name
                  },
                ),
                fallbackUrl:
                    'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png', // Fallback server
                maxZoom: 19,
                // backgroundColor: Colors.grey[300],
                backgroundColor: Colors.grey[300],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                        widget.location.latitude, widget.location.longitude),
                    width: 80,
                    height: 80,
                    child: Column(
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '±${widget.location.accuracy.toStringAsFixed(1)}m',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                          size: 40,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.white70,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _isSatelliteView
                    ? '© ESRI World Imagery'
                    : '© OpenStreetMap contributors',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
