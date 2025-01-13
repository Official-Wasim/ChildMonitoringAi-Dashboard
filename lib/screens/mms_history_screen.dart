import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  bool _isLoading = true; // Add loading state

  @override
  void initState() {
    super.initState();
    // _fetchMmsData(); // Fetch data function will be added later
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
        return AlertDialog(
          title: Text("Filter MMS"),
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
                value: "incoming",
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
                title: Text("Incoming MMS"),
              ),
              RadioListTile<String>(
                value: "outgoing",
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
                title: Text("Outgoing MMS"),
              ),
            ],
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text("MMS History"),
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
                      hintText: 'Search MMS...',
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
                  tooltip: "Filter MMS",
                ),
              ],
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
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                    ? Center(
                        child: CircularProgressIndicator(),
                      )
                    : _filteredMmsList.isEmpty
                        ? Center(
                            child: Text(
                              _errorMessage.isEmpty
                                  ? _selectedFilter == "incoming"
                                      ? 'No incoming MMS found matching "$_searchQuery".'
                                      : _selectedFilter == "outgoing"
                                          ? 'No outgoing MMS found matching "$_searchQuery".'
                                          : 'No MMS found matching "$_searchQuery".'
                                  : _errorMessage,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _filteredMmsList.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final mms = _filteredMmsList[index];
                              return MmsHistoryTile(
                                  mms: mms,
                                  formattedDate:
                                      _getFormattedDate(mms.timestamp));
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
