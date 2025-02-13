import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../../components/charts/stats_chart.dart';

class FetchDataService {
  static Future<List<ScreenTimeData>> fetchScreenTimeData(
      String phoneModel) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final List<ScreenTimeData> weekData = [];
    final now = DateTime.now();

    try {
      // Fetch last 7 days of data
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);

        final DatabaseReference appUsageRef = FirebaseDatabase.instance
            .ref()
            .child('users/${user.uid}/phones/$phoneModel/app_usage/$dateStr');

        final DatabaseEvent event = await appUsageRef.once();

        double totalHours = 0;
        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          int totalMilliseconds = 0;

          data.forEach((_, details) {
            if (details is Map && details.containsKey('usage_duration')) {
              totalMilliseconds += (details['usage_duration'] as int);
            }
          });

          totalHours = totalMilliseconds / (1000 * 60 * 60); // Convert to hours
        }

        weekData.add(ScreenTimeData(
            DateFormat('E').format(date), // Short day name (Mon, Tue, etc.)
            double.parse(totalHours.toStringAsFixed(1))));
      }

      return weekData;
    } catch (e) {
      debugPrint('Error fetching screen time data: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchRecentAlerts(
      String phoneModel, DateTime date) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final notificationsDate = DateFormat('yyyyMMdd').format(date);
      final DatabaseReference notificationsRef = FirebaseDatabase.instance
          .ref()
          .child(
              'users/${user.uid}/phones/$phoneModel/notifications/$notificationsDate');

      final DatabaseEvent event = await notificationsRef.once();
      final List<Map<String, dynamic>> alerts = [];

      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            // Safely handle potentially null values with null-aware operators and defaults
            alerts.add({
              'id': key?.toString() ?? '',
              'title': (value['title'] as String?) ?? 'Unknown Title',
              'body': (value['body'] as String?) ?? 'No description',
              'type': (value['type'] as String?) ?? 'unknown',
              'timestamp':
                  value['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
            });
          }
        });
      }

      // Sort alerts by timestamp in descending order (most recent first)
      alerts.sort(
          (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      return alerts;
    } catch (e) {
      print('Error fetching alerts: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchGeofenceTimeline(
      String phoneModel, DateTime date) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final notificationsDate = DateFormat('yyyyMMdd').format(date);
      final DatabaseReference notificationsRef = FirebaseDatabase.instance
          .ref()
          .child(
              'users/${user.uid}/phones/$phoneModel/notifications/$notificationsDate');

      final DatabaseEvent event = await notificationsRef.once();
      final List<Map<String, dynamic>> timeline = [];

      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            // Add null checks and default values
            final String type = (value['type'] as String?) ?? '';
            final String body = (value['body'] as String?) ?? '';
            final int timestamp = (value['timestamp'] as int?) ??
                DateTime.now().millisecondsSinceEpoch;

            if (type == 'geofence_alert') {
              String action = 'Unknown';
              String fenceName = 'Unknown Location';

              // Extract action and fence name from notification body
              if (body.toLowerCase().contains('entered')) {
                action = 'Entered';
                try {
                  fenceName =
                      body.split('entered ').last.split('.').first.trim();
                } catch (e) {
                  print('Error parsing entered fence name: $e');
                }
              } else if (body.toLowerCase().contains('left')) {
                action = 'Left';
                try {
                  fenceName = body.split('left ').last.split('.').first.trim();
                } catch (e) {
                  print('Error parsing exited fence name: $e');
                }
              }

              if (fenceName.isEmpty) {
                fenceName = 'Unknown Location';
              }

              timeline.add({
                'time': timestamp,
                'location': fenceName,
                'action': action,
              });
            }
          }
        });
      }

      // Sort timeline by timestamp in descending order
      timeline.sort((a, b) => (b['time'] as int).compareTo(a['time'] as int));
      return timeline;
    } catch (e) {
      print('Error fetching geofence timeline: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAppUsageData(
      String deviceId, DateTime date) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child(
              'users/${FirebaseAuth.instance.currentUser?.uid}/phones/$deviceId/app_usage/${DateFormat('yyyy-MM-dd').format(date)}')
          .get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return data.entries.map((entry) {
          final appData = Map<String, dynamic>.from(entry.value as Map);
          return {
            'category': entry.key,
            'minutes': appData['duration'] ?? 0.0,
            'openCount': appData['open_count'] ?? 0,
            'lastUsed': DateTime.fromMillisecondsSinceEpoch(
                appData['last_used'] ?? DateTime.now().millisecondsSinceEpoch),
            'firstUsed': DateTime.fromMillisecondsSinceEpoch(
                appData['first_used'] ?? DateTime.now().millisecondsSinceEpoch),
          };
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching app usage data: $e');
      return [];
    }
  }
}
