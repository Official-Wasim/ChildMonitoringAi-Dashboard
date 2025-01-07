import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WebVisitHistoryScreen extends StatefulWidget {
  const WebVisitHistoryScreen({Key? key}) : super(key: key);

  @override
  _WebVisitHistoryScreenState createState() => _WebVisitHistoryScreenState();
}

class _WebVisitHistoryScreenState extends State<WebVisitHistoryScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<WebVisit> _webVisitHistory = [];
  late String _userId; // Dynamic user ID
  final String phoneModel = 'sdk_gphone64_x86_64'; // Hardcoded phone model

  @override
  void initState() {
    super.initState();
    _fetchUserId(); // Fetch dynamic user ID
  }

  // Fetch user ID from FirebaseAuth
  Future<void> _fetchUserId() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      _fetchWebVisitHistory();
    } else {
      debugPrint('No user is signed in');
    }
  }

  // Fetch web visit history from Firebase
  Future<void> _fetchWebVisitHistory() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('User is signed out, aborting fetch');
        return;
      }

      debugPrint('Fetching web visit history for user $_userId...');

      final webVisitSnapshot = await _databaseRef
          .child('users/$_userId/phones/$phoneModel/web_visits')
          .get();

      if (webVisitSnapshot.exists) {
        final Map<String, dynamic> webVisitsData =
            Map<String, dynamic>.from(webVisitSnapshot.value as Map);

        final List<WebVisit> fetchedWebVisits = [];

        // Iterate through dates in the structure
        webVisitsData.forEach((date, visitsByDate) {
          if (visitsByDate is Map) {
            final Map<String, dynamic> visitsMap =
                Map<String, dynamic>.from(visitsByDate);

            // Loop through individual visits for each date
            visitsMap.forEach((key, value) {
              if (value is Map<String, dynamic>) {
                final webVisitMap = Map<String, dynamic>.from(value);

                // Add to the fetched list
                fetchedWebVisits.add(WebVisit(
                  url: webVisitMap['url'] ?? 'Unknown',
                  title: webVisitMap['title'] ?? 'Unknown',
                  timestamp: '$date ${DateTime.fromMillisecondsSinceEpoch(webVisitMap['timestamp'] ?? 0).toLocal()}',
                ));
              }
            });
          }
        });

        // Sort by timestamp in descending order
        fetchedWebVisits.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        setState(() {
          _webVisitHistory = fetchedWebVisits;
        });

        debugPrint('Fetched ${fetchedWebVisits.length} web visits');
      } else {
        debugPrint('No web visit history available');
        setState(() {
          _webVisitHistory = [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching web visit history: $e');
      setState(() {
        _webVisitHistory = [];
      });
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
                  'Web Visit History',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _webVisitHistory.isEmpty
                    ? Center(
                        child: Text(
                          'No web visit history available',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _webVisitHistory.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final webVisit = _webVisitHistory[index];
                          return WebVisitTile(webVisit: webVisit);
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

class WebVisit {
  final String url;
  final String title;
  final String timestamp;

  WebVisit({
    required this.url,
    required this.title,
    required this.timestamp,
  });
}

class WebVisitTile extends StatelessWidget {
  final WebVisit webVisit;

  const WebVisitTile({super.key, required this.webVisit});

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
              Icons.web,
              color: Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    webVisit.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    webVisit.url,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    webVisit.timestamp,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary.withOpacity(0.7),
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
}
