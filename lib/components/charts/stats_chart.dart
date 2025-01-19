import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

// Chart Data Models
class ChartData {
  final String category;
  final double value;
  ChartData(this.category, this.value);
}

class ScreenTimeData {
  final String day;
  final double hours;
  ScreenTimeData(this.day, this.hours);
}

class AppUsageData {
  final String category;
  final double percentage;
  AppUsageData(this.category, this.percentage);
}

// New Data Models
class CallStats {
  final String type;
  final int count;
  final Duration duration;
  CallStats(this.type, this.count, this.duration);
}

class WebsiteStats {
  final String category;
  final int visits;
  final Duration duration;
  WebsiteStats(this.category, this.visits, this.duration);
}

class StatsService {
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
    final snapshot = await _databaseRef
        .child('users/$userId/phones/$deviceId/calls/$date')
        .get();

    if (!snapshot.exists) {
      return {
        'incoming': 0,
        'outgoing': 0,
        'missed': 0,
        'totalDuration': 0,
        'totalCalls': 0,
        'details': [],
      };
    }

    final callsData = Map<String, dynamic>.from(snapshot.value as Map);
    int incoming = 0, outgoing = 0, missed = 0, totalDuration = 0;
    List<Map<String, dynamic>> callDetails = [];

    callsData.forEach((callId, callData) {
      final call = Map<String, dynamic>.from(callData as Map);
      callDetails.add(call);
      switch (call['type']) {
        case 'incoming':
          incoming++;
          totalDuration += (call['duration'] ?? 0) as int;
          break;
        case 'outgoing':
          outgoing++;
          totalDuration += (call['duration'] ?? 0) as int;
          break;
        case 'missed':
          missed++;
          break;
      }
    });

    return {
      'incoming': incoming,
      'outgoing': outgoing,
      'missed': missed,
      'totalDuration': totalDuration,
      'totalCalls': callsData.length,
      'details': callDetails,
    };
  }

  Future<Map<String, dynamic>> _fetchMessageStats(String userId,
      String deviceId, String currentDate, String previousDate) async {
    // Fetch current day messages
    final currentDayStats =
        await _fetchDayMessageStats(userId, deviceId, currentDate);
    final previousDayStats =
        await _fetchDayMessageStats(userId, deviceId, previousDate);

    double trend = 0;
    if (previousDayStats['total'] > 0) {
      trend = ((currentDayStats['total'] - previousDayStats['total']) /
              previousDayStats['total']) *
          100;
    }

    return {
      'current': currentDayStats,
      'previous': previousDayStats,
      'trend': trend,
    };
  }

  Future<Map<String, dynamic>> _fetchDayMessageStats(
      String userId, String deviceId, String date) async {
    final smsSnapshot = await _databaseRef
        .child('users/$userId/phones/$deviceId/sms/$date')
        .get();
    final mmsSnapshot = await _databaseRef
        .child('users/$userId/phones/$deviceId/mms/$date')
        .get();
    final socialMediaSnapshot = await _databaseRef
        .child('users/$userId/phones/$deviceId/social_media_messages/$date')
        .get();

    int smsCount = smsSnapshot.exists ? (smsSnapshot.value as Map).length : 0;
    int mmsCount = mmsSnapshot.exists ? (mmsSnapshot.value as Map).length : 0;
    int socialMediaCount = 0;

    if (socialMediaSnapshot.exists) {
      final platforms = socialMediaSnapshot.value as Map;
      platforms.forEach((platform, messages) {
        socialMediaCount += (messages as Map).length;
      });
    }

    return {
      'sms': smsCount,
      'mms': mmsCount,
      'socialMedia': socialMediaCount,
      'total': smsCount + mmsCount + socialMediaCount,
    };
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
}

// Add this color utility class at the top level
class ChartColors {
  static const List<Color> palette = [
    Color(0xFF6C5CE7), // Purple
    Color(0xFF00B894), // Green
    Color(0xFFFF7675), // Coral
    Color(0xFF74B9FF), // Light Blue
    Color(0xFFFFBE76), // Orange
    Color(0xFFB2BEC3), // Gray
    Color(0xFF0984E3), // Blue
    Color(0xFFE84393), // Pink
    Color(0xFFE17055), // Dark Orange
    Color(0xFF00CEC9), // Turquoise
  ];

  static Color getColor(int index) {
    return palette[index % palette.length];
  }

  static Color getColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'incoming':
        return const Color(0xFF00B894); // Green
      case 'outgoing':
        return const Color(0xFF6C5CE7); // Purple
      case 'missed':
        return const Color(0xFFFF7675); // Coral
      case 'messages':
        return const Color(0xFF74B9FF); // Light Blue
      case 'social':
        return const Color(0xFFFFBE76); // Orange
      case 'others':
        return const Color(0xFFB2BEC3); // Gray
      default:
        return getColor(category.hashCode);
    }
  }
}

// Chart Widgets
class ScreenTimeChart extends StatelessWidget {
  final List<ScreenTimeData> data;
  const ScreenTimeChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        overflowMode: LegendItemOverflowMode.wrap,
        textStyle: const TextStyle(fontSize: 12),
        orientation: LegendItemOrientation.horizontal,
        itemPadding: 8,
      ),
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: 8,
        interval: 2,
        majorGridLines: const MajorGridLines(width: 0),
      ),
      plotAreaBorderWidth: 0,
      series: <ChartSeries<ScreenTimeData, String>>[
        SplineAreaSeries<ScreenTimeData, String>(
          name: 'Screen Time',
          dataSource: data,
          xValueMapper: (ScreenTimeData data, _) => data.day,
          yValueMapper: (ScreenTimeData data, _) => data.hours,
          color: ChartColors.palette[0].withOpacity(0.2),
          borderColor: ChartColors.palette[0],
          borderWidth: 3,
          splineType: SplineType.natural,
        ),
      ],
    );
  }
}

class WebVisitsPieChart extends StatelessWidget {
  final List<ChartData> data;
  const WebVisitsPieChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SfCircularChart(
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        orientation: LegendItemOrientation.horizontal,
        overflowMode: LegendItemOverflowMode.wrap,
        textStyle: const TextStyle(fontSize: 12),
        iconHeight: 12,
        iconWidth: 12,
        padding: 8,
        itemPadding: 8,
      ),
      series: <CircularSeries>[
        DoughnutSeries<ChartData, String>(
          dataSource: data,
          xValueMapper: (ChartData data, _) => data.category,
          yValueMapper: (ChartData data, _) => data.value,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            labelIntersectAction: LabelIntersectAction.shift,
            connectorLineSettings: ConnectorLineSettings(
              type: ConnectorType.curve,
              length: '20%',
            ),
            textStyle: TextStyle(fontSize: 10),
          ),
          dataLabelMapper: (ChartData data, _) =>
              '${data.category}\n${data.value.toStringAsFixed(1)}%',
          enableTooltip: true,
          animationDuration: 1500,
          innerRadius: '60%',
          // Add different colors for each segment
          pointColorMapper: (ChartData data, _) =>
              ChartColors.getColor(data.hashCode),
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x: point.y%',
      ),
    );
  }
}

class AppUsageChart extends StatelessWidget {
  final List<AppUsageData> data;
  const AppUsageChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      series: <ChartSeries>[
        BarSeries<AppUsageData, String>(
          dataSource: data,
          xValueMapper: (AppUsageData data, _) => data.category,
          yValueMapper: (AppUsageData data, _) => data.percentage,
          color: const Color(0xFF6C5CE7),
          pointColorMapper: (AppUsageData data, _) =>
              ChartColors.getColor(data.hashCode),
        )
      ],
    );
  }
}

class CommunicationOverviewChart extends StatelessWidget {
  final Map<String, int> data;
  const CommunicationOverviewChart({Key? key, required this.data})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
        // Implementation for communication overview chart
        );
  }
}

class CallDistributionPieChart extends StatelessWidget {
  final Map<String, dynamic> callStats;
  const CallDistributionPieChart({Key? key, required this.callStats})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Process call details to get contact-wise stats
    final Map<String, int> contactStats = {};
    final List<Map<String, dynamic>> details =
        List<Map<String, dynamic>>.from(callStats['details'] ?? []);

    // Group calls by contact
    for (var call in details) {
      final String contact = call['contactName'] ?? call['number'] ?? 'Unknown';
      contactStats[contact] = (contactStats[contact] ?? 0) + 1;
    }

    // Convert to ChartData and sort by total calls
    List<ChartData> chartData = contactStats.entries
        .map((e) => ChartData(e.key, e.value.toDouble()))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take top 5 contacts and group others
    if (chartData.length > 5) {
      double othersValue =
          chartData.sublist(5).fold(0, (sum, item) => sum + item.value);
      chartData = chartData.sublist(0, 5)
        ..add(ChartData('Others', othersValue));
    }

    return SfCircularChart(
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        orientation: LegendItemOrientation.horizontal,
        overflowMode: LegendItemOverflowMode.wrap,
        textStyle: const TextStyle(fontSize: 12),
        iconHeight: 12,
        iconWidth: 12,
        padding: 8,
        itemPadding: 8,
      ),
      series: <CircularSeries>[
        DoughnutSeries<ChartData, String>(
          dataSource: chartData,
          xValueMapper: (ChartData data, _) => data.category,
          yValueMapper: (ChartData data, _) => data.value,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            labelIntersectAction: LabelIntersectAction.shift,
            connectorLineSettings: ConnectorLineSettings(
              type: ConnectorType.curve,
              length: '20%',
            ),
            textStyle: TextStyle(fontSize: 10),
          ),
          dataLabelMapper: (ChartData data, _) =>
              '${data.category}\n${data.value.toInt()} calls', // Changed to show actual count
          enableTooltip: true,
          animationDuration: 1500,
          innerRadius: '60%',
          pointColorMapper: (ChartData data, _) =>
              ChartColors.getColor(data.hashCode),
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x: point.y calls', // Updated tooltip format
      ),
    );
  }
}

class TopAppsUsageChart extends StatelessWidget {
  final List<AppUsageData> data;
  const TopAppsUsageChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
        // Implementation for top apps usage chart
        );
  }
}

class AppCategoryBreakdownChart extends StatelessWidget {
  final List<ChartData> data;
  const AppCategoryBreakdownChart({Key? key, required this.data})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SfCircularChart(
        // Implementation for app category breakdown chart
        );
  }
}
