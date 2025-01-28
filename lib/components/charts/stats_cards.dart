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
          title: 'Total Screen Time',
          value: '4h 23m',
          icon: Icons.timer,
          color: const Color(0xFF6C5CE7),
          trend: '+15%',
          onTrendTap: showTrendInfo,
          context: context, // Pass context to _buildStatCard
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
            _showCallTrendInfo(
              context, 
              callStats['totalCalls'] ?? 0,
              callStats['yesterdayTotal'] ?? 0,
              callStats['trend'] ?? 0.0
            );
          },
          context: context,
        ),
        _buildStatCard(
          title: 'Apps Used',
          value: '8',
          icon: Icons.apps,
          color: const Color(0xFFFF4757),
          trend: '0%',
          onTrendTap: showTrendInfo,
          context: context, // Pass context to _buildStatCard
        ),
      ],
    );
  }

  static void _showCallTrendInfo(
    BuildContext context, 
    int todayCalls, 
    int yesterdayCalls, 
    double trend
  ) {
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

  // Add all other card widgets from stats_screen.dart here...
  // For brevity, I'm showing just a few examples. You should move all card widgets here.

  static Widget buildScreenTimeCard(List<ScreenTimeData> data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Screen Time Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
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

  static Widget buildCommunicationStats() {
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
                  value: '147',
                  color: const Color(0xFF6C5CE7),
                ),
                _buildCommunicationMetric(
                  icon: Icons.call,
                  label: 'Calls',
                  value: '23',
                  color: const Color(0xFF81ECEC),
                ),
                _buildCommunicationMetric(
                  icon: Icons.people,
                  label: 'Contacts',
                  value: '48',
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

  static Widget buildLocationTimelineCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location Timeline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('Location Timeline Content'), // Placeholder content
          ],
        ),
      ),
    );
  }

  static Widget buildAppUsageSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Usage Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('App Usage Summary Content'), // Placeholder content
          ],
        ),
      ),
    );
  }

  static Widget buildTopAppsUsageChart() {
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
            SizedBox(
              width: double.infinity,
              height: 250, // Adjusted height
              child: TopAppsUsageChart(data: []), // Pass actual data here
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildAppCategoryBreakdown() {
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

  static Widget buildDetailedAppList() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed App Usage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('Detailed App List Content'), // Placeholder content
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

  static Widget buildTopAppsCard() {
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
            // Add your top apps content here
            const Text('Top Apps Statistics'),
          ],
        ),
      ),
    );
  }
}
