import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'stats_chart.dart';

class StatsCard {
  static Widget buildQuickStats({
    required BuildContext context, // Add this parameter
    required Map<String, dynamic> callStats,
    required int totalMessagesCount,
    required double messageTrend,
    required double callTrend,
    required Function(BuildContext, String, String, IconData, Color, String)
        showTrendInfo,
    required BoxConstraints constraints,
    required int screenTimeMinutes, // Add this parameter
    required double screenTimeTrend, // Add this parameter
    required int appsUsed, // Add this parameter
    required double appsUsedTrend, // Add this parameter
  }) {
    final isTablet = constraints.maxWidth > 600;
    final crossAxisCount = isTablet ? 4 : 2;
    final childAspectRatio = isTablet ? 1.8 : 1.5;
    final spacing = constraints.maxWidth * 0.04;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
      children: [
        _buildStatCard(
          title: 'Screen Time',
          value: _formatScreenTime(screenTimeMinutes), // Use the parameter
          icon: Icons.timer,
          color: const Color(0xFF6C5CE7),
          trend: '${screenTimeTrend.toStringAsFixed(1)}%', // Use the parameter
          onTrendTap: showTrendInfo,
          context: context,
        ),
        _buildStatCard(
          title: 'Messages',
          value: '$totalMessagesCount',
          icon: Icons.message,
          color: const Color(0xFF81ECEC),
          trend: messageTrend >= 0
              ? '+${messageTrend.toStringAsFixed(1)}%'
              : '${messageTrend.toStringAsFixed(1)}%',
          onTrendTap: showTrendInfo,
          context: context, // Pass context to _buildStatCard
        ),
        _buildStatCard(
          title: 'Calls',
          value: '${callStats['totalCalls'] ?? 0}',
          icon: Icons.phone,
          color: const Color(0xFFFFA502),
          trend: callStats['trend'] != null
              ? '${(callStats['trend'] as double).toStringAsFixed(1)}%'
              : '0%',
          onTrendTap: (context, title, value, icon, color, trend) {
            _showCallTrendInfo(context, callStats['totalCalls'] ?? 0,
                callStats['yesterdayTotal'] ?? 0, callStats['trend'] ?? 0.0);
          },
          context: context,
        ),
        _buildStatCard(
          title: 'Apps Used',
          value: '$appsUsed', // Use the parameter
          icon: Icons.apps,
          color: const Color(0xFFFF4757),
          trend: '${appsUsedTrend.toStringAsFixed(1)}%', // Use the parameter
          onTrendTap: showTrendInfo,
          context: context, // Pass context to _buildStatCard
        ),
      ],
    );
  }

  static void _showCallTrendInfo(
      BuildContext context, int todayCalls, int yesterdayCalls, double trend) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.phone, color: const Color(0xFFFFA502)),
              const SizedBox(width: 8),
              const Text('Call Statistics'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Today\'s calls: $todayCalls'),
              Text('Yesterday\'s calls: $yesterdayCalls'),
              const SizedBox(height: 8),
              Text(
                'Trend: ${trend.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: trend >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
    required Function(BuildContext, String, String, IconData, Color, String)
        onTrendTap,
    required BuildContext context, // Add this parameter
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final fontSize = isTablet ? 16.0 : 12.0;
    final iconSize = isTablet ? 24.0 : 20.0;

    return Container(
      padding: EdgeInsets.all(screenSize.width * 0.03),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(screenSize.width * 0.02),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: iconSize),
              ),
              GestureDetector(
                onTap: () => onTrendTap(context, title, value, icon, color,
                    trend), // Use context here
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: trend.startsWith('+')
                        ? Colors.green.withOpacity(0.1)
                        : trend.startsWith('-')
                            ? Colors.red.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        trend,
                        style: TextStyle(
                          color: trend.startsWith('+')
                              ? Colors.green
                              : trend.startsWith('-')
                                  ? Colors.red
                                  : Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.info_outline,
                        size: 12,
                        color: trend.startsWith('+')
                            ? Colors.green
                            : trend.startsWith('-')
                                ? Colors.red
                                : Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 28 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatScreenTime(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${remainingMinutes}m';
    }
    return '${remainingMinutes}m';
  }

  // Add all other card widgets from stats_screen.dart here...
  // For brevity, I'm showing just a few examples. You should move all card widgets here.

  static Widget buildScreenTimeCard(List<ScreenTimeData> data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Add this
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Screen Time Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16), // Reduced spacing
            SizedBox(
              height:
                  280, // Fixed height to accommodate both chart and summary cards
              child: ScreenTimeChart(data: data),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildWebVisitsPieChart(
      List<ChartData> webVisitsData, bool isLoading) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Web Visits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (webVisitsData.isEmpty)
              const Center(
                child: Text(
                  'No web visits data available',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 250, // Adjusted height
                child: WebVisitsPieChart(data: webVisitsData),
              ),
          ],
        ),
      ),
    );
  }

  static Widget buildCommunicationStats({
    required int messageCount,
    required int callCount,
    required int contactCount,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Communication Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCommunicationMetric(
                  icon: Icons.message,
                  label: 'Messages',
                  value: messageCount.toString(),
                  color: const Color(0xFF6C5CE7),
                ),
                _buildCommunicationMetric(
                  icon: Icons.call,
                  label: 'Calls',
                  value: callCount.toString(),
                  color: const Color(0xFF81ECEC),
                ),
                _buildCommunicationMetric(
                  icon: Icons.people,
                  label: 'Contacts',
                  value: contactCount.toString(),
                  color: const Color(0xFFFFA502),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildCommunicationMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  static Widget buildSmsStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SMS Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('SMS Statistics Content'), // Placeholder content
          ],
        ),
      ),
    );
  }

  static Widget buildMessagingAppsCard() {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messaging Apps',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Messaging Apps Content'), // Placeholder content
          ],
        ),
      ),
    );
  }

  static Widget buildWebsiteStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Website Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('Website Statistics Content'), // Placeholder content
          ],
        ),
      ),
    );
  }

  static Widget buildCallHistoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Calls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('Call History Content'), // Placeholder content
          ],
        ),
      ),
    );
  }

  static Widget buildContactsAnalysisCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contacts Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('Contacts Analysis Content'), // Placeholder content
          ],
        ),
      ),
    );
  }

  static Widget buildAppUsageSummary({
    required int appOpens,
    required int appsUsed,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'App Usage Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Today',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildUsageSummaryItem(
                  icon: Icons.open_in_new,
                  label: 'App Opens',
                  value: '$appOpens times',
                  color: Colors.green,
                ),
                _buildUsageSummaryItem(
                  icon: Icons.apps,
                  label: 'Apps Used',
                  value: '$appsUsed apps',
                  color: Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildUsageSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildAppCategoryBreakdownSimple() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('App Category Breakdown Content'), // Placeholder content
          ],
        ),
      ),
    );
  }

  static Widget buildCallsPieChart(Map<String, dynamic> callStats) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Call Statistics', // Changed from 'Call Distribution'
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Top contacts by call frequency', // Added subtitle
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 250, // Adjusted height
              child: CallDistributionPieChart(callStats: callStats),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildDigitalWellbeingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Digital Wellbeing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Add your digital wellbeing content here
            const Text('Digital Wellbeing Statistics'),
          ],
        ),
      ),
    );
  }

  static Widget buildTopAppsCard(List<Map<String, dynamic>> topApps) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Apps Used',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (topApps.isEmpty)
              const Center(
                child: Text(
                  'No app usage data available',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Column(
                children: topApps.map((app) {
                  final duration = app['duration'] as int;
                  final minutes = duration ~/ 60000; // Convert ms to minutes
                  final hours = minutes ~/ 60;
                  final remainingMinutes = minutes % 60;
                  final timeString = hours > 0
                      ? '${hours}h ${remainingMinutes}m'
                      : '${remainingMinutes}m';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: ChartColors.getColor(app['package'].hashCode)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              app['appName']
                                  .toString()
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                color: ChartColors.getColor(
                                    app['package'].hashCode),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app['appName'].toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                timeString,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  static Widget buildTopAppsUsageChart(List<Map<String, dynamic>> topApps) {
    // Convert app usage data to minutes for chart
    final List<Map<String, dynamic>> chartData = topApps.map((app) {
      final duration = app['duration'] as int;
      final minutes = duration ~/ 60000; // Convert ms to minutes
      return {
        'name': app['appName'].toString(),
        'usage': minutes,
        'color': ChartColors.getColor(app['package'].hashCode),
      };
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Apps Usage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (chartData.isEmpty)
              const Center(
                child: Text('No app usage data available', 
                  style: TextStyle(color: Colors.grey)),
              )
            else
              SizedBox(
                height: 250,
                child: SfCartesianChart(
                  primaryXAxis: CategoryAxis(
                    majorGridLines: const MajorGridLines(width: 0),
                    labelStyle: const TextStyle(fontSize: 12),
                    labelRotation: -45,
                  ),
                  primaryYAxis: NumericAxis(
                    minimum: 0,
                    interval: 30,
                    labelFormat: '{value}m',
                    majorGridLines: const MajorGridLines(
                      width: 0.5,
                      color: Colors.grey,
                      dashArray: [5, 5],
                    ),
                  ),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CartesianSeries>[
                    ColumnSeries<Map<String, dynamic>, String>(
                      dataSource: chartData,
                      xValueMapper: (Map<String, dynamic> data, _) => data['name'],
                      yValueMapper: (Map<String, dynamic> data, _) => data['usage'],
                      pointColorMapper: (Map<String, dynamic> data, _) => data['color'],
                      borderRadius: BorderRadius.circular(8),
                      width: 0.5,
                      spacing: 0.2,
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        labelAlignment: ChartDataLabelAlignment.top,
                        textStyle: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget buildDetailedAppList(List<Map<String, dynamic>> detailedApps) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isExpanded = false;
        
        String _formatDuration(int milliseconds) {
          final minutes = milliseconds ~/ 60000;
          final hours = minutes ~/ 60;
          final remainingMinutes = minutes % 60;
          return hours > 0 ? '${hours}h ${remainingMinutes}m' : '${remainingMinutes}m';
        }

        String _formatTimestamp(int timestamp) {
          final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final now = DateTime.now();
          final difference = now.difference(dateTime);

          if (difference.inMinutes < 60) {
            return '${difference.inMinutes}m ago';
          } else if (difference.inHours < 24) {
            return '${difference.inHours}h ago';
          } else {
            return DateFormat('h:mm a').format(dateTime);
          }
        }

        String _formatTimeOnly(int timestamp) {
          return DateFormat('h:mm a')
              .format(DateTime.fromMillisecondsSinceEpoch(timestamp));
        }

        final displayedApps = isExpanded ? detailedApps : detailedApps.take(5).toList();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Detailed App Usage',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (detailedApps.length > 5)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            isExpanded = !isExpanded;
                          });
                        },
                        child: Text(
                          isExpanded ? 'Show Less' : 'Show All',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (detailedApps.isEmpty)
                  const Center(
                    child: Text(
                      'No app usage data available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      children: displayedApps.map((app) => Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: ChartColors.getColor(app['package'].hashCode)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  app['name'][0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        ChartColors.getColor(app['package'].hashCode),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        app['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(app['usage']),
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Opens: ${app['opens']}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'First: ${_formatTimeOnly(app['firstOpen'])}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Last: ${_formatTimestamp(app['lastUsed'])}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
