import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AppInfo {
  final String name;
  final bool isInstalled;
  final DateTime timestamp;

  AppInfo(this.name, this.isInstalled, this.timestamp);
}

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  _AppsScreenState createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<AppInfo> appsList = [];

  @override
  void initState() {
    super.initState();
    _fetchAppsData();
  }

  Future<void> _fetchAppsData() async {
    final uniqueUserId = 'uniqueUserId'; // Replace with dynamic user ID
    final phoneModel =
        'sdk_gphone64_x86_64'; // Replace with dynamic phone model

    try {
      final appsSnapshot = await _databaseRef
          .child('users/$uniqueUserId/phones/$phoneModel/apps')
          .get();

      if (appsSnapshot.exists) {
        final Map<String, dynamic> appsData =
            Map<String, dynamic>.from(appsSnapshot.value as Map);

        final List<AppInfo> fetchedApps = [];

        appsData.forEach((key, value) {
          final appMap = Map<String, dynamic>.from(value);
          fetchedApps.add(AppInfo(
            appMap['name'] ?? 'Unknown',
            appMap['status'] == 'installed',
            DateTime.fromMillisecondsSinceEpoch(
                int.tryParse(appMap['timestamp'].toString()) ?? 0),
          ));
        });

        setState(() {
          appsList = fetchedApps;
        });
      }
    } catch (e) {
      debugPrint('Error fetching apps data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apps'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(); // Navigate back to the previous screen
          },
        ),
      ),
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
                  'Apps',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: appsList.length,
                  itemBuilder: (context, index) {
                    final app = appsList[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        leading: Icon(Icons.apps, size: 50), // App icon
                        title: Text(app.name,
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle:
                            Text(app.isInstalled ? 'Installed' : 'Uninstalled'),
                        trailing: Text(
                          '${app.timestamp.day}/${app.timestamp.month}/${app.timestamp.year}',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
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
