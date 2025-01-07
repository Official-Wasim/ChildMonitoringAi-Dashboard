import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({Key? key}) : super(key: key);

  @override
  _CallHistoryScreenState createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<CallInfo> _callList = [];
  String _errorMessage = ''; // Add an error message field

  @override
  void initState() {
    super.initState();
    _fetchCallData();
  }

  Future<void> _fetchCallData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _callList = [];
        _errorMessage = 'User is not logged in'; // Set error message
      });
      return;
    }

    final String uniqueUserId = user.uid;
    final String phoneModel = 'sdk_gphone64_x86_64'; // Replace with dynamic phone model

    try {
      final callSnapshot = await _databaseRef
          .child('users/$uniqueUserId/phones/$phoneModel/calls')
          .get();

      if (callSnapshot.exists) {
        final Map<String, dynamic> callsByDate =
            Map<String, dynamic>.from(callSnapshot.value as Map);

        final List<CallInfo> fetchedCalls = [];

        callsByDate.forEach((dateKey, callEntries) {
          final Map<String, dynamic> callEntriesMap =
              Map<String, dynamic>.from(callEntries);

          callEntriesMap.forEach((callKey, callData) {
            final callMap = Map<String, dynamic>.from(callData);
            fetchedCalls.add(CallInfo(
              name:
                  'Unknown (${callMap['number'] ?? 'Unknown'})', // Display number along with contact name
              phoneNumber: callMap['number'] ?? 'Unknown',
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                  callMap['timestamp'] is int
                      ? callMap['timestamp']
                      : int.tryParse(callMap['timestamp'].toString()) ?? 0), // Ensure timestamp is converted to DateTime
              type: _getCallType(callMap['type'].toString()), // Ensure type is parsed as a string
              duration: Duration(
                  seconds: callMap['duration'] is int
                      ? callMap['duration']
                      : int.tryParse(callMap['duration'].toString()) ?? 0), // Ensure duration is an integer
            ));
          });
        });

        fetchedCalls.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Sort by timestamp in descending order

        setState(() {
          _callList = fetchedCalls;
          _errorMessage = ''; // Clear error message
        });
      } else {
        setState(() {
          _callList = [];
          _errorMessage = 'No call data found'; // Set error message
        });
      }
    } catch (e) {
      debugPrint('Error fetching call data: $e');
      setState(() {
        _callList = [];
        _errorMessage = 'Error fetching call data: $e'; // Set error message
      });
    }
  }

  List<CallInfo> _getAllCalls() {
    return _callList;
  }

  DateTime _parseTimestamp(String timestamp) {
    try {
      // If the timestamp is a Unix timestamp (e.g., seconds or milliseconds since epoch)
      if (timestamp.length > 10) {
        final int timestampInMilliseconds = int.parse(timestamp);
        return DateTime.fromMillisecondsSinceEpoch(timestampInMilliseconds);
      } else {
        // Attempt to parse the string as a normal DateTime format
        return DateTime.parse(timestamp);
      }
    } catch (e) {
      debugPrint('Error parsing timestamp: $e');
      return DateTime.now(); // Return the current time in case of a parsing error
    }
  }

  CallType _getCallType(String type) {
    switch (type) {
      case '1': // Missed call
        return CallType.missed;
      case '2': // Outgoing call
        return CallType.outgoing;
      case '3': // Incoming call
        return CallType.incoming;
      default:
        return CallType.unknown;
    }
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
                  'Call History',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _callList.isEmpty
                    ? Center(
                        child: _errorMessage.isEmpty
                            ? CircularProgressIndicator()
                            : Text(_errorMessage),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _getAllCalls().length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final call = _getAllCalls()[index];
                          return CallHistoryTile(call: call);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CallInfo {
  final String name;
  final String phoneNumber;
  final DateTime timestamp;
  final CallType type;
  final Duration? duration;

  CallInfo({
    required this.name,
    required this.phoneNumber,
    required this.timestamp,
    required this.type,
    this.duration,
  });
}

class CallHistoryTile extends StatelessWidget {
  final CallInfo call;

  const CallHistoryTile({super.key, required this.call});

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
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getCallTypeColor(call.type).withOpacity(0.3),
                    _getCallTypeColor(call.type).withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getCallTypeIcon(call.type),
                color: _getCallTypeColor(call.type),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    call.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getCallDirectionIcon(call.type),
                        size: 14,
                        color: theme.colorScheme.secondary.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(call.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  if (call.duration != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDuration(call.duration!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCallTypeColor(CallType type) {
    switch (type) {
      case CallType.missed:
        return Colors.red;
      case CallType.incoming:
        return Colors.green;
      case CallType.outgoing:
        return Colors.blue;
      case CallType.unknown:
        return Colors.grey;
    }
  }

  IconData _getCallTypeIcon(CallType type) {
    switch (type) {
      case CallType.missed:
        return Icons.phone_missed;
      case CallType.incoming:
        return Icons.phone_callback;
      case CallType.outgoing:
        return Icons.phone_forwarded;
      case CallType.unknown:
        return Icons.phone_disabled;
    }
  }

  IconData _getCallDirectionIcon(CallType type) {
    switch (type) {
      case CallType.missed:
        return Icons.call_missed;
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.unknown:
        return Icons.block;
    }
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
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime); // Show date and time
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

enum CallType { missed, incoming, outgoing, unknown }
