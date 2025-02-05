import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class FetchDataService {
  static Future<Map<String, dynamic>> fetchTodaysOverview(
      String phoneModel, DateTime date) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'screenTime': 0, 'appsUsed': 0, 'alertsCount': 0};

    try {
      final appUsageDate = DateFormat('yyyy-MM-dd').format(date);
      final notificationsDate = DateFormat('yyyyMMdd').format(date);

      // Fetch app usage data
      final DatabaseReference appUsageRef = FirebaseDatabase.instance
          .ref()
          .child(
              'users/${user.uid}/phones/$phoneModel/app_usage/$appUsageDate');

      // Fetch notifications data
      final DatabaseReference notificationsRef = FirebaseDatabase.instance
          .ref()
          .child(
              'users/${user.uid}/phones/$phoneModel/notifications/$notificationsDate');

      // Get both data simultaneously
      final results = await Future.wait([
        appUsageRef.once(),
        notificationsRef.once(),
      ]);

      final appUsageEvent = results[0] as DatabaseEvent;
      final notificationsEvent = results[1] as DatabaseEvent;

      // Process app usage data
      int totalDuration = 0;
      int appsUsed = 0;

      if (appUsageEvent.snapshot.exists) {
        final data = appUsageEvent.snapshot.value as Map<dynamic, dynamic>;
        appsUsed = data.length;
        data.forEach((package, details) {
          if (details is Map && details.containsKey('usage_duration')) {
            totalDuration += (details['usage_duration'] as int);
          }
        });
      }

      // Count notifications
      int alertsCount = 0;
      if (notificationsEvent.snapshot.exists) {
        final notifications =
            notificationsEvent.snapshot.value as Map<dynamic, dynamic>;
        alertsCount = notifications.length; // Count unique notification IDs
      }

      // Convert milliseconds to minutes
      final screenTimeMinutes = totalDuration ~/ 60000;

      return {
        'screenTime': screenTimeMinutes,
        'appsUsed': appsUsed,
        'alertsCount': alertsCount,
      };
    } catch (e) {
      return {'screenTime': 0, 'appsUsed': 0, 'alertsCount': 0};
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
}
