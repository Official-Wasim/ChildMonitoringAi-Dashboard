import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart'; // Add this import

class MmsHistoryScreen extends StatefulWidget {
  const MmsHistoryScreen({Key? key}) : super(key: key);

  @override
  _MmsHistoryScreenState createState() => _MmsHistoryScreenState();
}

class _MmsHistoryScreenState extends State<MmsHistoryScreen> {
  List<MmsInfo> _mmsList = [];
  List<MmsInfo> _filteredMmsList = [];
  String _errorMessage = '';
  String _searchQuery = ""; // Add search query state
  String _selectedFilter = "all"; // "all", "incoming", "outgoing"
  final RefreshController _refreshController = RefreshController(initialRefresh: false); // Add this line

  static const int _itemsPerPage = 20;
  int _currentPage = 0;
  bool _hasMoreData = true;

  List<MmsInfo> get _paginatedMms {
    final startIndex = 0;
    final endIndex = (_currentPage + 1) * _itemsPerPage;
    if (startIndex >= _filteredMmsList.length) return [];
    return _filteredMmsList.sublist(
        startIndex, endIndex.clamp(0, _filteredMmsList.length));
  }

  void _loadMoreData() {
    setState(() {
      _currentPage++;
      _hasMoreData =
          (_currentPage + 1) * _itemsPerPage < _filteredMmsList.length;
    });
  }

  @override
  void initState() {
    super.initState();
    // _fetchMmsData(); // Fetch data function will be added later
  }

  Future<void> _fetchMmsData({bool isRefresh = false}) async {
    // ...existing code...
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
    final mms = _mmsList;
    setState(() {
      _filteredMmsList = mms.where((mms) {
        if (_selectedFilter == "incoming") {
          return mms.type == 1;
        } else if (_selectedFilter == "outgoing") {
          return mms.type == 2;
        }
        return true; // Default is "all"
      }).where((mms) {
        if (_searchQuery.isEmpty) {
          return true;
        }
        return mms.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            mms.body.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
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
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.filter_list,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      "Filter Messages",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                ...["all", "incoming", "outgoing"].map((filter) {
                  String title = filter[0].toUpperCase() + filter.substring(1);
                  if (filter == "all") title = "Show All";
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
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
                          padding: EdgeInsets.symmetric(
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
                                filter == "incoming"
                                    ? Icons.call_received
                                    : filter == "outgoing"
                                        ? Icons.call_made
                                        : Icons.all_inclusive,
                                color: _selectedFilter == filter
                                    ? Colors.blue
                                    : Colors.grey,
                                size: 20,
                              ),
                              SizedBox(width: 12),
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
                              Spacer(),
                              if (_selectedFilter == filter)
                                Icon(
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
                SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
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

  String _getFormattedDate(int timestamp) {
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final DateTime now = DateTime.now();

    if (_isToday(dateTime, now)) {
      return 'Today ${DateFormat('HH:mm').format(dateTime)}';
    } else if (_isYesterday(dateTime, now)) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('yyyy-MM-dd HH:mm')
          .format(dateTime); // Show date and time
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
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true, // Add this line
      appBar: PreferredSize(
        preferredSize:
            Size.fromHeight(160), // Adjusted for the search bar height
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
              "MMS History",
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
                            hintText: 'Search MMS...',
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
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.filter_list, color: Colors.white),
                        onPressed: _showFilterDialog,
                        tooltip: "Filter MMS",
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
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Showing ${_paginatedMms.length} of ${_filteredMmsList.length} MMS',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Expanded(
                child: _filteredMmsList.isEmpty
                    ? Center(
                        child: Text(
                          _errorMessage.isEmpty
                              ? 'No MMS found'
                              : _errorMessage,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : SmartRefresher(
                        controller: _refreshController,
                        enablePullDown: true,
                        onRefresh: () => _fetchMmsData(isRefresh: true),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount:
                              _paginatedMms.length + (_hasMoreData ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index >= _paginatedMms.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: ElevatedButton(
                                    onPressed: _loadMoreData,
                                    child: const Text('Load More'),
                                  ),
                                ),
                              );
                            }
                            final mms = _paginatedMms[index];
                            return MmsHistoryTile(
                                mms: mms,
                                formattedDate: _getFormattedDate(mms.timestamp));
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MmsInfo {
  final String date;
  final String address;
  final String body;
  final int timestamp;
  final int type;

  MmsInfo({
    required this.date,
    required this.address,
    required this.body,
    required this.timestamp,
    required this.type,
  });
}

class MmsHistoryTile extends StatelessWidget {
  final MmsInfo mms;
  final String formattedDate;

  const MmsHistoryTile({
    super.key,
    required this.mms,
    required this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mmsDate = DateTime.fromMillisecondsSinceEpoch(mms.timestamp);

    // Check the type of MMS and set the icon
    IconData messageIcon =
        mms.type == 2 ? Icons.arrow_outward : Icons.arrow_downward;

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Full Message'),
            content: Text(mms.body),
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
                messageIcon,
                color: Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mms.address,
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
                      mms.body,
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
