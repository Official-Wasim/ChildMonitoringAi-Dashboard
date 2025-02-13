import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // For formatting time
import 'package:url_launcher/url_launcher.dart'; // Add this import
import 'package:sticky_headers/sticky_headers/widget.dart'; // Correct import for StickyHeader
import 'package:pull_to_refresh/pull_to_refresh.dart'; // Add this import
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import 'package:flutter/services.dart'; // Add this import for clipboard

class WebVisitHistoryPage extends StatefulWidget {
  final String phoneModel; // Add this line

  const WebVisitHistoryPage({
    Key? key,
    required this.phoneModel,
  }) : super(key: key);

  @override
  _WebVisitHistoryPageState createState() => _WebVisitHistoryPageState();
}

class _WebVisitHistoryPageState extends State<WebVisitHistoryPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  late String _userId;
  Map<String, List<Map<String, dynamic>>> _webVisitHistory = {};
  List<Map<String, dynamic>> _filteredWebVisitHistory = [];
  bool _isLoading = true;
  static const int _itemsPerPage = 50; // Update to 50 items
  int _currentPage = 0;
  String _searchQuery = ""; // Add search query state
  bool _hasMoreData = true;
  List<Map<String, dynamic>> _allWebVisits = [];
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false); // Add this line

  // Add color scheme constants to match apps screen
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

  @override
  void initState() {
    super.initState();
    _initializeUserId();
  }

  Future<void> _initializeUserId() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        _userId = currentUser.uid;
      });
      await _fetchWebVisitHistory();
    } else {
      // Handle the case when no user is signed in
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No user signed in'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _fetchWebVisitHistory({bool isRefresh = false}) async {
    if (widget.phoneModel == 'Select Device') {
      setState(() {
        _isLoading = false;
        _allWebVisits = [];
        _filteredWebVisitHistory = [];
      });
      return;
    }

    if (_userId.isEmpty) return;
    try {
      final webVisitSnapshot = await _databaseRef
          .child(
              'users/$_userId/phones/${widget.phoneModel}/web_visits') // Use widget.phoneModel
          .get();

      if (webVisitSnapshot.exists) {
        final data = Map<String, dynamic>.from(webVisitSnapshot.value as Map);
        List<Map<String, dynamic>> allVisits = [];

        data.forEach((date, visitsByDate) {
          if (visitsByDate is Map) {
            final visits = (visitsByDate as Map).entries.map((entry) {
              final visit = Map<String, dynamic>.from(entry.value as Map);
              visit['date'] = date; // Store date with each visit
              return visit;
            }).toList();
            allVisits.addAll(visits);
          }
        });

        // Sort all visits by timestamp in descending order
        allVisits.sort(
            (a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

        setState(() {
          _allWebVisits = allVisits;
          _filteredWebVisitHistory = allVisits;
          _isLoading = false;
          _hasMoreData = allVisits.length > _itemsPerPage;
        });
      } else {
        setState(() {
          _allWebVisits = [];
          _filteredWebVisitHistory = [];
          _isLoading = false;
          _hasMoreData = false;
        });
      }
    } catch (e) {
      setState(() {
        _allWebVisits = [];
        _filteredWebVisitHistory = [];
        _isLoading = false;
        _hasMoreData = false;
      });
    }
    if (isRefresh) {
      _refreshController.refreshCompleted();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredWebVisitHistory = _allWebVisits.where((visit) {
        return visit['url']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            visit['title']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
      }).toList();
      _currentPage = 0;
      _hasMoreData = _filteredWebVisitHistory.length > _itemsPerPage;
    });
  }

  List<Map<String, dynamic>> get _paginatedList {
    final startIndex = 0;
    final endIndex = (_currentPage + 1) * _itemsPerPage;
    if (startIndex >= _filteredWebVisitHistory.length) return [];
    return _filteredWebVisitHistory.sublist(
        startIndex, endIndex.clamp(0, _filteredWebVisitHistory.length));
  }

  void _loadMoreData() {
    setState(() {
      _currentPage++;
      _hasMoreData =
          (_currentPage + 1) * _itemsPerPage < _filteredWebVisitHistory.length;
    });
  }

  Widget _highlightSearchText(String text) {
    if (_searchQuery.isEmpty) {
      return Text(text);
    }
    final matches = text.toLowerCase().split(_searchQuery.toLowerCase());
    if (matches.length <= 1) {
      return Text(text);
    }
    final List<TextSpan> spans = [];
    int start = 0;
    for (var match in matches) {
      if (match.isNotEmpty) {
        spans.add(TextSpan(text: text.substring(start, start + match.length)));
        start += match.length;
      }
      if (start < text.length) {
        spans.add(TextSpan(
          text: text.substring(start, start + _searchQuery.length),
          style: const TextStyle(backgroundColor: Colors.yellow),
        ));
        start += _searchQuery.length;
      }
    }
    return RichText(
        text: TextSpan(
            style: const TextStyle(color: Colors.black), children: spans));
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return "Invalid time";
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
    return DateFormat('dd MMM yyyy, HH:mm:ss')
        .format(dateTime); // Enhanced date format
  }

  Future<void> _launchURL(String urlString) async {
    // Clean up the URL string
    urlString = urlString.trim();

    // Add https:// if no protocol is specified
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }

    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(
        url,
        mode: LaunchMode.platformDefault,
      )) {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open: $urlString'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _truncateUrl(String url, int maxLines) {
    List<String> lines = url.split('\n');
    if (lines.length <= maxLines) return url;
    return '${lines.take(maxLines).join('\n')}...';
  }

  void _showUrlDialog(BuildContext context, Map<String, dynamic> visit) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding:
              const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Website Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.grey.shade600),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 24,
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  visit['url'] ?? 'No URL',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.blue.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${visit['packageName'] ?? 'Unknown App'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: visit['url'] ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('URL copied to clipboard'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy URL'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _launchURL(visit['url'] ?? '');
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupVisitsByDate(
      List<Map<String, dynamic>> visits) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var visit in visits) {
      if (visit['timestamp'] != null) {
        final date =
            DateTime.fromMillisecondsSinceEpoch(visit['timestamp']).toLocal();
        final dateStr = DateFormat('dd MMM yyyy').format(date);
        grouped.putIfAbsent(dateStr, () => []);
        grouped[dateStr]!.add(visit);
      }
    }
    return Map.fromEntries(grouped.entries.toList()
      ..sort((a, b) => DateFormat('dd MMM yyyy')
          .parse(b.key)
          .compareTo(DateFormat('dd MMM yyyy').parse(a.key))));
  }

  String _formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).round();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  Widget _buildVisitsList() {
    final groupedVisits = _groupVisitsByDate(_paginatedList);
    final theme = Theme.of(context);

    return ListView.builder(
      physics: const BouncingScrollPhysics(), // Add bouncy physics
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: groupedVisits.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= groupedVisits.length) {
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

        final dateStr = groupedVisits.keys.elementAt(index);
        final visitsForDate = groupedVisits[dateStr]!;

        return StickyHeader(
          header: Container(
            color: Colors.transparent, // Set background to fully transparent
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${visitsForDate.length} visits',
                  style: const TextStyle(
                    color: primaryColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          content: Column(
            children: visitsForDate.map((visit) {
              String formattedTime = DateFormat('HH:mm:ss').format(
                  DateTime.fromMillisecondsSinceEpoch(visit['timestamp']));
              String duration = _formatDuration(visit['duration'] ?? 0);
              String packageName = visit['packageName'] ?? 'Unknown App';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () => _showUrlDialog(context, visit),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.link,
                                color: Colors.blue.shade700, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    visit['url'] ?? 'No URL',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    packageName,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        if (visit['title'] != null) ...[
                          Text(
                            visit['title'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  formattedTime,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.timer,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  duration,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize:
            const Size.fromHeight(kToolbarHeight + 60), // Changed from 160
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
              "Web Visit History",
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
                            hintText: 'Search visits...',
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        // Remove the top padding that was creating extra space
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
          child: Column(
            children: [
              // Remove the SizedBox that was adding extra space
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredWebVisitHistory.isEmpty
                        ? Center(
                            child: Text(
                              'No web visit history found\nmatching "$_searchQuery".',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          )
                        : SmartRefresher(
                            controller: _refreshController,
                            enablePullDown: true,
                            onRefresh: () =>
                                _fetchWebVisitHistory(isRefresh: true),
                            child: _buildVisitsList(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
