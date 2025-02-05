import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import 'dart:ui';
import '../models/location_info.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
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
  final MapController _mapController = MapController();

  Future<void> _openInGoogleMaps() async {
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${widget.location.latitude},${widget.location.longitude}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  Widget _buildCompass() {
    return Container(
      width: 100,
      height: 100,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: StreamBuilder<MapEvent>(
            stream: _mapController.mapEventStream,
            builder: (context, snapshot) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: (_mapController.rotation * pi) / 180,
                  child: CustomPaint(
                    painter: CompassPainter(),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Direction Letters
                        ...['N', 'E', 'S', 'W'].asMap().entries.map((entry) {
                          final index = entry.key;
                          final direction = entry.value;
                          return Positioned(
                            top: index == 0 ? 8 : null,
                            bottom: index == 2 ? 8 : null,
                            left: index == 3 ? 8 : null,
                            right: index == 1 ? 8 : null,
                            child: Text(
                              direction,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: direction == 'N' ? 16 : 14,
                                color: direction == 'N'
                                    ? Colors.red
                                    : Colors.black87,
                              ),
                            ),
                          );
                        }),
                        // Center Arrow
                        Icon(
                          Icons.navigation,
                          size: 24,
                          color: Colors.blue.shade700,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

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
      floatingActionButton: FloatingActionButton(
        onPressed: _openInGoogleMaps,
        backgroundColor: Colors.white,
        child: Icon(
          Icons.map_outlined,
          color: Colors.blue,
        ),
        tooltip: 'Open in Google Maps',
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
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
                    'User-Agent': 'Child Monitoring Ai/1.0',
                  },
                ),
                fallbackUrl: 'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
                maxZoom: 19,
                backgroundColor: Colors.grey[300],
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(
                      widget.location.latitude,
                      widget.location.longitude,
                    ),
                    radius: widget.location.accuracy,
                    color: Colors.blue.withOpacity(0.2),
                    borderColor: Colors.blue.withOpacity(0.4),
                    borderStrokeWidth: 1,
                    useRadiusInMeter: true,
                  ),
                ],
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
            right: 16,
            top: 16,
            child: _buildCompass(),
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

// Move CompassPainter class outside of _MapScreenState
class CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw compass circle
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius - 2, paint);

    // Draw cardinal direction lines
    paint.color = Colors.grey.withOpacity(0.3);
    for (var i = 0; i < 8; i++) {
      final angle = (i * pi / 4);
      final lineLength = i % 2 == 0 ? radius - 15 : radius - 20;
      canvas.drawLine(
        center,
        Offset(
          center.dx + cos(angle) * lineLength,
          center.dy + sin(angle) * lineLength,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
