import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:sticky_headers/sticky_headers/widget.dart';

class AppsScreen extends StatefulWidget {
  final String? phoneModel;

  const AppsScreen({Key? key, this.phoneModel}) : super(key: key);

  @override
  _AppsScreenState createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  // Add color scheme constants to match other screens
  static const Color primaryColor = Color(0xFF1A237E); // Deep Indigo
  static const Color secondaryColor =
      Color(0xFF283593); // Slightly lighter Indigo
  static const Color accentColor = Color(0xFF3949AB); // Bright Indigo
  static const Color backgroundColor =
      Color(0xFFF8F9FF); // Light blue-tinted white
  static const Color backgroundGradientStart = Color(0xFFFFFFFF); // Pure white
  static const Color backgroundGradientEnd =
      Color(0xFFF0F2FF); // Very light indigo
  static const Color surfaceColor = Colors.white;

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  String _userId = "";
  String get _phoneModel => widget.phoneModel ?? "sdk_gphone64_x86_64";
  Map<String, List<Map<String, dynamic>>> _appsData = {};
  List<Map<String, dynamic>> _filteredApps = [];
  bool _isLoading = true;
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  String _searchQuery = "";
  String _selectedFilter = "all"; // "all", "installed", "uninstalled"
  static const int _itemsPerPage = 20;
  int _currentPage = 0;
  bool _hasMoreData = true;

  List<Map<String, dynamic>> get _paginatedApps {
    final startIndex = 0;
    final endIndex = (_currentPage + 1) * _itemsPerPage;
    if (startIndex >= _filteredApps.length) return [];
    return _filteredApps.sublist(
        startIndex, endIndex.clamp(0, _filteredApps.length));
  }

  void _loadMoreData() {
    setState(() {
      _currentPage++;
      _hasMoreData = (_currentPage + 1) * _itemsPerPage < _filteredApps.length;
    });
  }

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
      final appsSnapshot = await _databaseRef
          .child('users/$_userId/phones/$_phoneModel/apps')
          .get();

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
            'category': appData['category'] ?? 'user_installed',
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

  Future<int> fetchAppCount() async {
    if (_userId.isEmpty) return 0;
    try {
      final appsSnapshot = await _databaseRef
          .child('users/$_userId/phones/$_phoneModel/apps')
          .get();

      if (appsSnapshot.exists) {
        final data = Map<String, dynamic>.from(appsSnapshot.value as Map);
        return data.length;
      }
    } catch (e) {
      // Handle error
    }
    return 0;
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
        return app['appName']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            app['packageName']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
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
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFF5F6FF), // Very light indigo
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.filter_list,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Filter Apps",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...["all", "installed", "uninstalled"].map((filter) {
                  String title = filter[0].toUpperCase() + filter.substring(1);
                  if (filter == "all") title = "Show All";
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _selectedFilter = filter;
                            _applyFilters();
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedFilter == filter
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedFilter == filter
                                  ? Colors.blue
                                  : Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                filter == "installed"
                                    ? Icons.check_circle_outline
                                    : filter == "uninstalled"
                                        ? Icons.remove_circle_outline
                                        : Icons.all_inclusive,
                                color: _selectedFilter == filter
                                    ? Colors.blue
                                    : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                title,
                                style: TextStyle(
                                  color: _selectedFilter == filter
                                      ? Colors.blue
                                      : Colors.black87,
                                  fontWeight: _selectedFilter == filter
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              const Spacer(),
                              if (_selectedFilter == filter)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
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

  String _formatSize(num? sizeInBytes) {
    if (sizeInBytes == null || sizeInBytes == 0) return "0 MB";
    return "${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB"; // Convert bytes to MB
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Map<String, List<Map<String, dynamic>>> _groupAppsByDate(
      List<Map<String, dynamic>> apps) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var app in apps) {
      final dateStr = DateFormat('dd MMM yyyy').format(
        DateTime.fromMillisecondsSinceEpoch(app['timestamp'] ?? 0),
      );
      grouped.putIfAbsent(dateStr, () => []);
      grouped[dateStr]!.add(app);
    }
    return Map.fromEntries(grouped.entries.toList()
      ..sort((a, b) => DateFormat('dd MMM yyyy')
          .parse(b.key)
          .compareTo(DateFormat('dd MMM yyyy').parse(a.key))));
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'installed':
        return Colors.green;
      case 'updated':
        return Colors.amber;
      case 'uninstalled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'installed':
        return Icons.check_circle;
      case 'updated':
        return Icons.system_update;
      case 'uninstalled':
        return Icons.remove_circle;
      default:
        return Icons.help_outline;
    }
  }

  Color _getIconBackgroundColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'installed':
        return Colors.green;
      case 'updated':
        return Colors.amber;
      case 'uninstalled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildAppsList() {
    final groupedApps = _groupAppsByDate(_paginatedApps);
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: groupedApps.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= groupedApps.length) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: TextButton(
                onPressed: _loadMoreData,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Load More',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        final dateStr = groupedApps.keys.elementAt(index);
        final appsForDate = groupedApps[dateStr]!;

        return StickyHeader(
          header: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryColor, secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    dateStr,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${appsForDate.length} apps',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          content: Column(
            children: appsForDate.map((app) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _getIconBackgroundColor(app['status'])
                                      .withOpacity(0.3),
                                  _getIconBackgroundColor(app['status'])
                                      .withOpacity(0.1),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.apps,
                              color: _getIconBackgroundColor(app['status']),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app['appName'] ?? 'Unknown App',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  app['packageName'] ?? 'Unknown Package',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildInfoChip(
                            context,
                            icon: Icons.system_update,
                            label: app['category'] == 'system'
                                ? 'System App'
                                : 'User Installed',
                            color: app['category'] == 'system'
                                ? Colors.grey
                                : Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _buildInfoChip(
                            context,
                            icon: _getStatusIcon(app['status']),
                            label: app['status']?.toString().toUpperCase() ??
                                'N/A',
                            color: _getStatusColor(app['status']),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'v${app['version']}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .withOpacity(0.7),
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sd_storage_outlined,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatSize(app['size']),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary
                                          .withOpacity(0.7),
                                    ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimestamp(app['timestamp']),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary
                                          .withOpacity(0.7),
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 60),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, secondaryColor],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              "Apps",
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(80), // Changed from 100
              child: Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 20, // Changed from 30
                  top: 8, // Changed from 12
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          onChanged: _onSearchChanged,
                          style: theme.textTheme.bodyMedium,
                          decoration: InputDecoration(
                            hintText: 'Search apps...',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                            prefixIcon:
                                const Icon(Icons.search, color: Colors.blue),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon:
                            const Icon(Icons.filter_list, color: Colors.white),
                        onPressed: _showFilterDialog,
                        tooltip: "Filter Apps",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8EAF6), // Light Indigo 50
              Color(0xFFC5CAE9), // Indigo 100
              Color(0xFFE8EAF6), // Light Indigo 50
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          // Wrap with SafeArea
          child: Column(
            children: [
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredApps.isEmpty
                      ? Center(
                          child: Text(
                            'No apps found matching "$_searchQuery".',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : Expanded(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Found ${_filteredApps.length} apps',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              Expanded(
                                child: SmartRefresher(
                                  controller: _refreshController,
                                  enablePullDown: true,
                                  onRefresh: () =>
                                      _fetchAppsData(isRefresh: true),
                                  child: _buildAppsList(),
                                ),
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
