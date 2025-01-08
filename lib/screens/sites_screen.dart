import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // For formatting time
import 'package:url_launcher/url_launcher.dart'; // Add this import

class WebVisitHistoryPage extends StatefulWidget {
  @override
  _WebVisitHistoryPageState createState() => _WebVisitHistoryPageState();
}

class _WebVisitHistoryPageState extends State<WebVisitHistoryPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  String _userId = ""; // Initialize as empty
  final String _phoneModel =
      "sdk_gphone64_x86_64"; // Replace dynamically if needed

  Map<String, List<Map<String, dynamic>>> _webVisitHistory = {};
  List<Map<String, dynamic>> _filteredWebVisitHistory = [];
  bool _isLoading = true;
  static const int _itemsPerPage = 1; // Show one date per page
  int _currentPage = 0;
  String _searchQuery = ""; // Add search query state

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

  Future<void> _fetchWebVisitHistory() async {
    if (_userId.isEmpty) return;
    try {
      final webVisitSnapshot = await _databaseRef
          .child('users/$_userId/phones/$_phoneModel/web_visits')
          .get();

      if (webVisitSnapshot.exists) {
        final data = Map<String, dynamic>.from(webVisitSnapshot.value as Map);
        final Map<String, List<Map<String, dynamic>>> parsedData = {};

        data.forEach((date, visitsByDate) {
          if (visitsByDate is Map) {
            final visits = (visitsByDate as Map).entries.map((entry) {
              return Map<String, dynamic>.from(entry.value as Map);
            }).toList();

            // Sort visits by timestamp in descending order
            visits.sort(
                (a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

            parsedData[date] = visits;
          }
        });

        // Sort dates in descending order
        final sortedKeys = parsedData.keys.toList()
          ..sort((a, b) => b.compareTo(a));
        final sortedData = {for (var key in sortedKeys) key: parsedData[key]!};

        setState(() {
          _webVisitHistory = sortedData;
          _filteredWebVisitHistory = sortedData.entries
              .expand((entry) => entry.value)
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _webVisitHistory = {};
          _filteredWebVisitHistory = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _webVisitHistory = {};
        _filteredWebVisitHistory = [];
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final visits = _webVisitHistory.entries
        .expand((entry) => entry.value)
        .toList();
    setState(() {
      _filteredWebVisitHistory = visits.where((visit) {
        return visit['url'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
               visit['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
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
    return RichText(text: TextSpan(style: const TextStyle(color: Colors.black), children: spans));
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return "Invalid time";
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
    return DateFormat('HH:mm:ss').format(dateTime); // Format as HH:MM:SS
  }

  Future<void> _launchURL(String urlString) async {
    final Uri? url = Uri.tryParse(urlString);
    if (url != null && await canLaunchUrl(url)) {
      try {
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          throw 'Could not launch $urlString';
        }
      } catch (e) {
        print('Error launching URL: $e');
        // Optionally show an error message to the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the link: $urlString')),
        );
      }
    } else {
      print('Invalid URL: $urlString');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid URL: $urlString')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_webVisitHistory.length / _itemsPerPage).ceil();
    final currentPageData = _webVisitHistory.entries
        .skip(_currentPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text("Web Visit History"),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search visits...',
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
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredWebVisitHistory.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No web visit history found matching "$_searchQuery".',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(8.0),
                        children: currentPageData.map((entry) {
                          final date = entry.key;
                          final visits = entry.value;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 4,
                              child: Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12.0),
                                    decoration: const BoxDecoration(
                                      color: Colors.blueAccent,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      "Date: $date",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  ...visits.map((visit) {
                                    return ListTile(
                                      leading: IconButton(
                                        icon: const Icon(
                                          Icons.link,
                                          color: Colors.blueAccent,
                                        ),
                                        onPressed: () => _launchURL(visit['url'] ?? ''),
                                      ),
                                      title: _highlightSearchText(visit['url'] ?? 'No URL'),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _highlightSearchText(visit['title'] ?? 'No Title'),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Visited at: ${_formatTimestamp(visit['timestamp'])}",
                                            style: const TextStyle(
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                        horizontal: 16.0,
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_currentPage > 0)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 12.0),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _currentPage--;
                                  });
                                },
                                child: const Text("Previous"),
                              ),
                            const SizedBox(width: 16.0),
                            if (_currentPage < totalPages - 1)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 12.0),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _currentPage++;
                                  });
                                },
                                child: const Text("Next"),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}
