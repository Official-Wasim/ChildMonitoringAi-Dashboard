import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class AppsScreen extends StatefulWidget {
  @override
  _AppsScreenState createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  String _userId = "";
  final String _phoneModel = "sdk_gphone64_x86_64"; // Replace dynamically if needed
  Map<String, List<Map<String, dynamic>>> _appsData = {};
  List<Map<String, dynamic>> _filteredApps = [];
  bool _isLoading = true;
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  String _searchQuery = "";
  String _selectedFilter = "all"; // "all", "installed", "uninstalled"

  @override
  void initState() {
    super.initState();
    _fetchUserId();
  }

  Future<void> _fetchUserId() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _userId = user.uid;
        });
        _fetchAppsData();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAppsData({bool isRefresh = false}) async {
    if (_userId.isEmpty) return;
    try {
      final appsSnapshot = await _databaseRef.child('users/$_userId/phones/$_phoneModel/apps').get();

      if (appsSnapshot.exists) {
        final data = Map<String, dynamic>.from(appsSnapshot.value as Map);

        if (data.isEmpty) {
          setState(() {
            _appsData = {};
            _isLoading = false;
          });
          return;
        }

        final List<Map<String, dynamic>> parsedData = data.entries.map((entry) {
          final appData = Map<String, dynamic>.from(entry.value as Map);
          return {
            'appName': appData['appName'] ?? 'Unknown App',
            'packageName': appData['packageName'] ?? 'Unknown Package',
            'size': appData['size'] ?? 0,
            'status': appData['status'] ?? 'Unknown',
            'timestamp': appData['timestamp'] ?? 0,
            'version': appData['version'] ?? 'Unknown',
          };
        }).toList();

        parsedData.sort(
            (a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

        setState(() {
          _appsData = {'apps': parsedData};
          _applyFilters();
          _isLoading = false;
        });
      } else {
        setState(() {
          _appsData = {};
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _appsData = {};
        _isLoading = false;
      });
    }
    if (isRefresh) {
      _refreshController.refreshCompleted();
    }
  }

  void _applyFilters() {
    final apps = _appsData['apps'] ?? [];
    setState(() {
      _filteredApps = apps.where((app) {
        if (_selectedFilter == "installed") {
          return app['status'].toLowerCase() == "installed";
        } else if (_selectedFilter == "uninstalled") {
          return app['status'].toLowerCase() == "uninstalled";
        }
        return true; // Default is "all"
      }).where((app) {
        return app['appName'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            app['packageName'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Filter Apps"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: "all",
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
                title: Text("Show All"),
              ),
              RadioListTile<String>(
                value: "installed",
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
                title: Text("Installed Apps"),
              ),
              RadioListTile<String>(
                value: "uninstalled",
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
                title: Text("Uninstalled Apps"),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null || timestamp == 0) return "Invalid time";
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text("Apps"),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search apps...',
                      prefixIcon: Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.filter_list),
                  onPressed: _showFilterDialog,
                  tooltip: "Filter Apps",
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Fetching apps data..."),
                ],
              ),
            )
          : _filteredApps.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No apps found matching "$_searchQuery".',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SmartRefresher(
                  controller: _refreshController,
                  enablePullDown: true,
                  onRefresh: () => _fetchAppsData(isRefresh: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredApps.length,
                    itemBuilder: (context, index) {
                      var app = _filteredApps[index];
                      return Card(
                        color: Colors.blueGrey[50],
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          leading: Icon(
                            Icons.apps,
                            size: 40,
                            color: app['status'] == 'installed'
                                ? Colors.green
                                : Colors.red,
                          ),
                          title: Text(
                            app['appName'] ?? 'Unknown App',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Package: ${app['packageName']}"),
                              const SizedBox(height: 4),
                              Text("Version: ${app['version']}"),
                              const SizedBox(height: 4),
                              Text(
                                "Size: ${app['size']} KB",
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Status: ${app['status']}",
                                style: TextStyle(
                                  color: app['status'] == 'installed'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Installed at: ${_formatTimestamp(app['timestamp'])}",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
