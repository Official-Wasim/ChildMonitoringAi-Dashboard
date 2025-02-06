import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../components/charts/stats_chart.dart';

class UserStatsService {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  Future<Map<String, dynamic>> fetchStatsData(
      String userId, String deviceId) async {
    final specificDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final previousDate = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    try {
      final results = await Future.wait([
        _fetchCallStats(userId, deviceId, specificDate),
        _fetchMessageStats(userId, deviceId, specificDate, previousDate),
        _fetchWebVisits(userId, deviceId, specificDate),
      ]);

      return {
        'callStats': results[0],
        'messageStats': results[1],
        'webVisits': results[2],
      };
    } catch (e) {
      debugPrint('Error fetching stats data: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _fetchCallStats(
      String userId, String deviceId, String date) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    try {
      final results = await Future.wait([
        _databaseRef.child('users/$userId/phones/$deviceId/calls/$today').get(),
        _databaseRef
            .child('users/$userId/phones/$deviceId/calls/$yesterday')
            .get(),
      ]);

      final todaySnapshot = results[0];
      final yesterdaySnapshot = results[1];

      // Count total number of calls for today
      int todayTotal = 0;
      List<Map<String, dynamic>> callDetails = [];

      if (todaySnapshot.exists) {
        final todayCalls = todaySnapshot.value as Map<dynamic, dynamic>;
        todayTotal = todayCalls.length;

        // Store call details for pie chart
        todayCalls.forEach((key, value) {
          if (value is Map) {
            callDetails.add(Map<String, dynamic>.from(value));
          }
        });
      }

      // Count yesterday's calls
      int yesterdayTotal = 0;
      if (yesterdaySnapshot.exists) {
        final yesterdayCalls = yesterdaySnapshot.value as Map<dynamic, dynamic>;
        yesterdayTotal = yesterdayCalls.length;
      }

      // Calculate trend
      double callTrend = 0;
      if (yesterdayTotal > 0) {
        callTrend = ((todayTotal - yesterdayTotal) / yesterdayTotal) * 100;
      }

      debugPrint('Today\'s total calls: $todayTotal');
      debugPrint('Yesterday\'s total calls: $yesterdayTotal');
      debugPrint('Call trend: $callTrend%');

      return {
        'totalCalls': todayTotal,
        'yesterdayTotal': yesterdayTotal,
        'trend': callTrend,
        'details': callDetails,
      };
    } catch (e) {
      debugPrint('Error fetching call stats: $e');
      return {
        'totalCalls': 0,
        'yesterdayTotal': 0,
        'trend': 0.0,
        'details': [],
      };
    }
  }

  Future<Map<String, dynamic>> _fetchMessageStats(String userId,
      String deviceId, String currentDate, String previousDate) async {
    try {
      // Fetch current day messages
      final currentDayStats =
          await _fetchDayMessages(userId, deviceId, DateTime.now());
      final previousDayStats = await _fetchDayMessages(
          userId, deviceId, DateTime.now().subtract(const Duration(days: 1)));

      double trend = 0;
      if (previousDayStats > 0) {
        trend = ((currentDayStats - previousDayStats) / previousDayStats) * 100;
      }

      return {
        'current': {
          'total': currentDayStats,
        },
        'previous': {
          'total': previousDayStats,
        },
        'trend': trend,
      };
    } catch (e) {
      debugPrint('Error fetching message stats: $e');
      return {
        'current': {'total': 0},
        'previous': {'total': 0},
        'trend': 0.0,
      };
    }
  }

  Future<int> _fetchDayMessages(
      String userId, String deviceId, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    int totalMessages = 0;

    try {
      final results = await Future.wait([
        _databaseRef.child('users/$userId/phones/$deviceId/sms/$dateStr').get(),
        _databaseRef.child('users/$userId/phones/$deviceId/mms/$dateStr').get(),
        _databaseRef
            .child(
                'users/$userId/phones/$deviceId/social_media_messages/$dateStr')
            .get(),
      ]);

      // Count SMS messages
      if (results[0].exists) {
        final smsData = results[0].value as Map<dynamic, dynamic>;
        totalMessages += smsData.length;
      }

      // Count MMS messages
      if (results[1].exists) {
        final mmsData = results[1].value as Map<dynamic, dynamic>;
        totalMessages += mmsData.length;
      }

      // Count social media messages
      if (results[2].exists) {
        final socialData = results[2].value as Map<dynamic, dynamic>;
        socialData.forEach((platform, messages) {
          if (messages is Map) {
            final platformMessages = messages as Map<dynamic, dynamic>;
            totalMessages += platformMessages.length;
          }
        });
      }

      return totalMessages;
    } catch (e) {
      debugPrint('Error fetching messages for $dateStr: $e');
      return 0;
    }
  }

  Future<List<ChartData>> _fetchWebVisits(
      String userId, String deviceId, String date) async {
    try {
      final snapshot = await _databaseRef
          .child('users/$userId/phones/$deviceId/web_visits/$date')
          .get();

      if (!snapshot.exists) return [];

      final visitsData = Map<String, dynamic>.from(snapshot.value as Map);
      Map<String, int> domainVisits = {};

      // Process each visit entry
      visitsData.forEach((visitId, value) {
        if (value != null) {
          final visit = Map<String, dynamic>.from(value as Map);
          String url = visit['url'] as String? ?? '';

          // Extract domain from URL
          String domain = _extractDomain(url);
          if (domain.isNotEmpty) {
            domainVisits[domain] = (domainVisits[domain] ?? 0) + 1;
          }
        }
      });

      // Convert to percentage-based ChartData
      return _processWebVisitsData(domainVisits);
    } catch (e) {
      debugPrint('Error fetching web visits: $e');
      return [];
    }
  }

  String _extractDomain(String url) {
    try {
      // Handle URLs that might not start with http/https
      if (!url.startsWith('http') && !url.startsWith('https')) {
        url = 'https://$url';
      }

      final uri = Uri.parse(url);
      String domain = uri.host;

      // Remove www. prefix if present
      if (domain.startsWith('www.')) {
        domain = domain.substring(4);
      }

      // Get the main domain part (e.g., "bookmyshow.com" from "in.bookmyshow.com")
      final parts = domain.split('.');
      if (parts.length > 2) {
        return '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
      }

      return domain;
    } catch (e) {
      debugPrint('Error extracting domain from URL: $url, error: $e');
      return url.split('/')[0];
    }
  }

  List<ChartData> _processWebVisitsData(Map<String, int> domainVisits) {
    int totalVisits = domainVisits.values.fold(0, (sum, count) => sum + count);

    // Convert visits to percentages and create ChartData objects
    var data = domainVisits.entries.map((entry) {
      double percentage = (entry.value / totalVisits) * 100;
      return ChartData(entry.key, percentage);
    }).toList();

    // Sort by percentage in descending order
    data.sort((a, b) => b.value.compareTo(a.value));

    // Group smaller percentages into "Others"
    if (data.length > 4) {
      double othersPercentage =
          data.sublist(4).fold(0.0, (sum, item) => sum + item.value);
      data = data.sublist(0, 4)..add(ChartData('Others', othersPercentage));
    }

    return data;
  }

  Future<List<ScreenTimeData>> fetchScreenTimeData(
      String userId, String deviceId) async {
    final List<ScreenTimeData> weekData = [];
    final now = DateTime.now();

    try {
      // Fetch last 7 days of data
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);

        final snapshot = await _databaseRef
            .child('users/$userId/phones/$deviceId/app_usage/$dateStr')
            .get();

        double totalHours = 0;
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
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

  Future<List<Map<String, dynamic>>> fetchTopApps(
      String userId, String deviceId, DateTime date) async {
    try {
      final appUsageDate = DateFormat('yyyy-MM-dd').format(date);
      final DatabaseReference appUsageRef = _databaseRef
          .child('users/$userId/phones/$deviceId/app_usage/$appUsageDate');

      final DataSnapshot snapshot = await appUsageRef.get();
      final List<Map<String, dynamic>> topApps = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        // Convert to list for sorting
        data.forEach((package, details) {
          if (details is Map && details.containsKey('usage_duration')) {
            topApps.add({
              'package': package,
              'appName':
                  details['app_name'] ?? package.toString().split('.').last,
              'duration': details['usage_duration'] as int,
              'lastUsed': details['last_used'] ?? 0,
            });
          }
        });

        // Sort by duration in descending order
        topApps.sort((a, b) => b['duration'].compareTo(a['duration']));
      }

      return topApps.take(5).toList(); // Return top 5 apps
    } catch (e) {
      debugPrint('Error fetching top apps: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchTodaysOverview(
      String userId, String deviceId, DateTime date) async {
    try {
      final appUsageDate = DateFormat('yyyy-MM-dd').format(date);
      final yesterdayDate = DateFormat('yyyy-MM-dd')
          .format(date.subtract(const Duration(days: 1)));
      final notificationsDate = DateFormat('yyyyMMdd').format(date);

      // Fetch data
      final results = await Future.wait([
        _databaseRef
            .child('users/$userId/phones/$deviceId/app_usage/$appUsageDate')
            .get(),
        _databaseRef
            .child('users/$userId/phones/$deviceId/app_usage/$yesterdayDate')
            .get(),
        _databaseRef
            .child(
                'users/$userId/phones/$deviceId/notifications/$notificationsDate')
            .get(),
      ]);

      // Process today's app usage data
      int todayDuration = 0;
      int todayAppsUsed = 0;
      int todayAppOpens = 0;

      if (results[0].exists) {
        final data = results[0].value as Map<dynamic, dynamic>;
        todayAppsUsed = data.length;
        data.forEach((package, details) {
          if (details is Map) {
            if (details.containsKey('usage_duration')) {
              todayDuration += (details['usage_duration'] as int);
            }
            if (details.containsKey('launch_count')) {
              todayAppOpens += (details['launch_count'] as int);
            }
          }
        });
      }

      // Process yesterday's data (only for screen time and apps used trends)
      int yesterdayDuration = 0;
      int yesterdayAppsUsed = 0;

      if (results[1].exists) {
        final data = results[1].value as Map<dynamic, dynamic>;
        yesterdayAppsUsed = data.length;
        data.forEach((package, details) {
          if (details is Map && details.containsKey('usage_duration')) {
            yesterdayDuration += (details['usage_duration'] as int);
          }
        });
      }

      // Calculate trends
      double screenTimeTrend = yesterdayDuration > 0
          ? ((todayDuration - yesterdayDuration) / yesterdayDuration) * 100
          : 0.0;

      double appsUsedTrend = yesterdayAppsUsed > 0
          ? ((todayAppsUsed - yesterdayAppsUsed) / yesterdayAppsUsed) * 100
          : 0.0;

      // Convert durations to minutes
      final todayMinutes = todayDuration ~/ 60000;
      final yesterdayMinutes = yesterdayDuration ~/ 60000;

      return {
        'screenTime': todayMinutes,
        'yesterdayScreenTime': yesterdayMinutes,
        'screenTimeTrend': screenTimeTrend,
        'appsUsed': todayAppsUsed,
        'yesterdayAppsUsed': yesterdayAppsUsed,
        'appsUsedTrend': appsUsedTrend,
        'appOpens': todayAppOpens,
      };
    } catch (e) {
      debugPrint('Error fetching overview: $e');
      return {
        'screenTime': 0,
        'yesterdayScreenTime': 0,
        'screenTimeTrend': 0.0,
        'appsUsed': 0,
        'yesterdayAppsUsed': 0,
        'appsUsedTrend': 0.0,
        'appOpens': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> fetchDetailedAppUsage(
      String userId, String deviceId, DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final DatabaseReference appUsageRef = _databaseRef
          .child('users/$userId/phones/$deviceId/app_usage/$dateStr');

      final DataSnapshot snapshot = await appUsageRef.get();
      final List<Map<String, dynamic>> detailedApps = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        data.forEach((package, details) {
          if (details is Map) {
            final duration = details['usage_duration'] as int? ?? 0;
            final opens = details['launch_count'] as int? ?? 0;
            final lastUsed = details['last_used'] as int? ?? 0;
            final firstOpen = details['first_open'] as int? ?? 0;

            detailedApps.add({
              'package': package,
              'name': details['app_name'] ?? package.toString().split('.').last,
              'usage': duration,
              'opens': opens,
              'lastUsed': lastUsed,
              'firstOpen': firstOpen,
            });
          }
        });

        // Sort by usage duration in descending order
        detailedApps.sort((a, b) => b['usage'].compareTo(a['usage']));
      }

      return detailedApps;
    } catch (e) {
      debugPrint('Error fetching detailed app usage: $e');
      return [];
    }
  }
}
