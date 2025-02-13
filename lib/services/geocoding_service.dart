import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class GeocodingService {
  static DateTime? _lastRequestTime;
  static const _minDelayBetweenRequests = Duration(seconds: 1);

  static Future<void> _waitForNextRequest() async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minDelayBetweenRequests) {
        await Future.delayed(_minDelayBetweenRequests - timeSinceLastRequest);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  static Future<String> getAddressFromCoordinates(
      double lat, double lon) async {
    try {
      await _waitForNextRequest();

      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1'),
        headers: {
          'User-Agent': 'YourAppName/1.0',
          'Accept-Language': 'en-US',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['display_name'] != null) {
          return data['display_name'];
        }
      }
      throw Exception('Failed to fetch address: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error in getAddressFromCoordinates: $e');
      return 'Location unavailable';
    }
  }

  static Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    await _waitForNextRequest();

    final response = await http.get(
      Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}',
      ),
      headers: {
        'User-Agent': 'YourAppName/1.0',
        'Accept-Language': 'en-US',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((item) => {
                'name': item['display_name'].toString().split(',').first,
                'address': item['display_name'],
                'lat': double.parse(item['lat']),
                'lon': double.parse(item['lon']),
              })
          .toList();
    }
    throw Exception('Failed to search location: ${response.statusCode}');
  }
}
