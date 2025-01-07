import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MmsHistoryScreen extends StatefulWidget {
  const MmsHistoryScreen({super.key});

  @override
  _MmsHistoryScreenState createState() => _MmsHistoryScreenState();
}

class _MmsHistoryScreenState extends State<MmsHistoryScreen> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    // Set the default filter to today
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'MMS History',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildFilterButton(
                        '2 Days Ago',
                        DateTime.now().subtract(const Duration(days: 2)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildFilterButton(
                        'Yesterday',
                        DateTime.now().subtract(const Duration(days: 1)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildFilterButton('Today', DateTime.now()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filteredMms().length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final mms = _filteredMms()[index];
                    return MmsHistoryTile(mms: mms);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<MmsInfo> _filteredMms() {
    if (_selectedDate == null) return _mockMms;
    return _mockMms.where((mms) {
      final mmsDate =
          DateTime(mms.timestamp.year, mms.timestamp.month, mms.timestamp.day);
      return mmsDate == _selectedDate; // Filter based on selected date
    }).toList();
  }

  Widget _buildFilterButton(String label, DateTime date) {
    final isSelected =
        _selectedDate == DateTime(date.year, date.month, date.day);
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedDate =
              isSelected ? null : DateTime(date.year, date.month, date.day);
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
        foregroundColor: isSelected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
      ),
      child: Text(label),
    );
  }
}

class MmsHistoryTile extends StatelessWidget {
  final MmsInfo mms;

  const MmsHistoryTile({
    super.key,
    required this.mms,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.message,
              color: Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mms.sender,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(mms.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mms.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateToCheck == today) {
      return 'Today ${DateFormat('HH:mm').format(dateTime)}';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('MMM d, HH:mm').format(dateTime);
    }
  }
}

class MmsInfo {
  final String sender;
  final String message;
  final DateTime timestamp;

  MmsInfo({
    required this.sender,
    required this.message,
    required this.timestamp,
  });
}

// Mock data for demonstration
final List<MmsInfo> _mockMms = [
  MmsInfo(
    sender: 'John Doe',
    message: 'Hey, are we still on for tomorrow?',
    timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
  ),
  MmsInfo(
    sender: 'Jane Smith',
    message: 'Don’t forget to bring the documents.',
    timestamp: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  MmsInfo(
    sender: 'Alice Johnson',
    message: 'Happy Birthday! 🎉',
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
  ),
  // Add more mock MMS as needed
]; 