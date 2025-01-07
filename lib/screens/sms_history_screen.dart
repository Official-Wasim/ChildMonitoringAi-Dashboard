import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SmsHistoryScreen extends StatefulWidget {
  const SmsHistoryScreen({Key? key}) : super(key: key);

  @override
  _SmsHistoryScreenState createState() => _SmsHistoryScreenState();
}

class _SmsHistoryScreenState extends State<SmsHistoryScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<SmsInfo> _smsList = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchSmsData();
  }

  Future<void> _fetchSmsData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'User is not logged in';
      });
      return;
    }

    final String uniqueUserId = user.uid; 
    final String phoneModel = 'sdk_gphone64_x86_64'; 

    try {
      final smsSnapshot = await _databaseRef
          .child('users/$uniqueUserId/phones/$phoneModel/sms')
          .get();

      if (smsSnapshot.exists) {
        final Map<String, dynamic> smsByDate =
            Map<String, dynamic>.from(smsSnapshot.value as Map);

        final List<SmsInfo> fetchedSms = [];

        smsByDate.forEach((dateKey, sms) {
          final Map<String, dynamic> smsEntries =
              Map<String, dynamic>.from(sms);

          smsEntries.forEach((key, value) {
            final smsData = Map<String, dynamic>.from(value);
            fetchedSms.add(SmsInfo(
              date: smsData['date'] ?? 'Unknown',
              address: smsData['address'] ?? 'Unknown',
              body: smsData['body'] ?? 'No message',
              timestamp: smsData['timestamp'] is int
                  ? smsData['timestamp']
                  : int.tryParse(smsData['timestamp'].toString()) ?? 0,
              type: smsData['type'] is int
                  ? smsData['type']
                  : int.tryParse(smsData['type'].toString()) ?? 1, // Ensure type is an integer
            ));
          });
        });

        fetchedSms.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Sort by timestamp in descending order

        setState(() {
          _smsList = fetchedSms;
          _errorMessage = ''; 
        });
      } else {
        setState(() {
          _smsList = [];
          _errorMessage = 'No SMS data found';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching SMS data: $e';
        _smsList = [];
      });
    }
  }

  List<SmsInfo> _getAllSms() {
    return _smsList;
  }

  String _getFormattedDate(int timestamp) {
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final DateTime now = DateTime.now();

    if (_isToday(dateTime, now)) {
      return 'Today ${DateFormat('HH:mm').format(dateTime)}';
    } else if (_isYesterday(dateTime, now)) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime); // Show date and time
    }
  }

  bool _isToday(DateTime dateTime, DateTime now) {
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  bool _isYesterday(DateTime dateTime, DateTime now) {
    final yesterday = now.subtract(const Duration(days: 1));
    return dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day;
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
                  'SMS History',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              Expanded(
                child: _smsList.isEmpty
                    ? Center(
                        child: _errorMessage.isEmpty
                            ? CircularProgressIndicator()
                            : Text(_errorMessage),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _getAllSms().length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final sms = _getAllSms()[index];
                          return SmsHistoryTile(
                              sms: sms, formattedDate: _getFormattedDate(sms.timestamp));
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

class SmsInfo {
  final String date;
  final String address;
  final String body;
  final int timestamp;
  final int type; // Add the type property

  SmsInfo({
    required this.date,
    required this.address,
    required this.body,
    required this.timestamp,
    required this.type, // Add the type parameter to the constructor
  });
}

class SmsHistoryTile extends StatelessWidget {
  final SmsInfo sms;
  final String formattedDate;

  const SmsHistoryTile({
    super.key,
    required this.sms,
    required this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final smsDate = DateTime.fromMillisecondsSinceEpoch(sms.timestamp);

    // Check the type of SMS and set the icon
    IconData messageIcon = sms.type == 2 ? Icons.arrow_outward : Icons.arrow_downward;

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Full Message'),
            content: Text(sms.body),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'),
              ),
            ],
          ),
        );
      },
      child: Container(
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
                messageIcon,  // Dynamically set icon based on SMS type
                color: Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sms.address,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sms.body,
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
      ),
    );
  }
}

