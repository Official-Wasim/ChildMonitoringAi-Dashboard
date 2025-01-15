import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // For formatting time
import 'package:url_launcher/url_launcher.dart'; // Add this import
import 'package:sticky_headers/sticky_headers/widget.dart'; // Correct import for StickyHeader
import 'package:pull_to_refresh/pull_to_refresh.dart'; // Add this import

class WebVisitHistoryPage extends StatefulWidget {
  final String phoneModel; // Add this line

  WebVisitHistoryPage({required this.phoneModel}); // Modify constructor

  @override
  _WebVisitHistoryPageState createState() => _WebVisitHistoryPageState();
}

class _WebVisitHistoryPageState extends State<WebVisitHistoryPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  String _userId = ""; // Initialize as empty
  // Remove the hardcoded phone model
  // final String _phoneModel = "sdk_gphone64_x86_64"; // Remove this line

  Map<String, List<Map<String, dynamic>>> _webVisitHistory = {};
  List<Map<String, dynamic>> _filteredWebVisitHistory = [];
  bool _isLoading = true;
  static const int _itemsPerPage = 20; // Changed to 20 items per page
  int _currentPage = 0;
  String _searchQuery = ""; // Add search query state
  bool _hasMoreData = true;
  List<Map<String, dynamic>> _allWebVisits = [];
  final RefreshController _refreshController = RefreshController(initialRefresh: false); // Add this line

  @override
  void initState() {
    super.initState();
    _fetchUserId();
  }

  Future<void> _fetchUserId() async {
    // Replace with actual user ID logic
    String userId = await getUserIdFromSomeService();
    setState(() {
      _userId = userId;
    });
    _fetchWebVisitHistory();
  }

  Future<String> getUserIdFromSomeService() async {
    // Mock implementation, replace with actual logic
    return Future.value("rgNHZYmejJd6D9r5nvyjSKknryA3");
  }

  Future<void> _fetchWebVisitHistory({bool isRefresh = false}) async {
    if (_userId.isEmpty) return;
    try {
      final webVisitSnapshot = await _databaseRef
          .child('users/$_userId/phones/${widget.phoneModel}/web_visits') // Use widget.phoneModel
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
      print('Error launching URL: $e');
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

  Widget _buildVisitsList() {
    final groupedVisits = _groupVisitsByDate(_filteredWebVisitHistory);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: groupedVisits.length,
      itemBuilder: (context, index) {
        final dateStr = groupedVisits.keys.elementAt(index);
        final visitsForDate = groupedVisits[dateStr]!;

        return StickyHeader(
          header: Container(
            color: Colors.transparent, // Set background to fully transparent
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue, // Change to Colors.blue
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dateStr,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '${visitsForDate.length} visits',
                  style: TextStyle(
                    color: Colors.grey.shade700,
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

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () => _launchURL(visit['url'] ?? ''),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.link,
                                color: Colors.blue.shade700, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: _highlightSearchText(
                                  visit['url'] ?? 'No URL'),
                            ),
                          ],
                        ),
                        Divider(height: 16),
                        _highlightSearchText(visit['title'] ?? 'No Title'),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
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
        preferredSize: Size.fromHeight(160),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(
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
              preferredSize: Size.fromHeight(100),
              child: Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 30,
                  top: 12,
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
                              offset: Offset(0, 2),
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
                                Icon(Icons.search, color: Colors.blue),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.withOpacity(0.1),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
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
                            onRefresh: () => _fetchWebVisitHistory(isRefresh: true),
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
