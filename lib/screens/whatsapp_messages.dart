import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:sticky_headers/sticky_headers/widget.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageScreen extends StatefulWidget {
  final String phoneModel;

  const MessageScreen({Key? key, required this.phoneModel}) : super(key: key);

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  late DatabaseReference _messagesRef;

  late Stream<DatabaseEvent> _messagesStream;
  List<Message> _messages = [];
  List<Message> _filteredMessages = [];
  bool _isLoading = false;
  int _pageSize = 30; // Set to 30 messages per page
  int _currentPage = 0;
  int _totalMessages = 0;
  String _searchQuery = ""; // Add search query state
  String _selectedFilter = "all"; // Add this with other state variables

  static const int _itemsPerPage = 20;
  bool _hasMoreData = true;

  List<Message> get _paginatedList {
    final startIndex = 0;
    final endIndex = (_currentPage + 1) * _itemsPerPage;
    if (startIndex >= _filteredMessages.length) return [];
    return _filteredMessages.sublist(
        startIndex, endIndex.clamp(0, _filteredMessages.length));
  }

  void _loadMoreData() {
    if (_hasMoreData) {
      setState(() {
        _currentPage++;
        _applyFilters(); // Apply filters when loading more data
        _hasMoreData =
            (_currentPage + 1) * _itemsPerPage < _filteredMessages.length;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _messagesRef = FirebaseDatabase.instance.ref(
          'users/${user.uid}/phones/${widget.phoneModel}/social_media_messages');
    }
    _messagesStream = _messagesRef.onValue; // Listening for changes
    _loadTotalMessages();
    _loadMoreMessages();
  }

  Future<void> _refreshMessages() async {
    setState(() {
      _messages = [];
      _filteredMessages = [];
      _currentPage = 0;
    });
    await _loadTotalMessages();
    await _loadMoreMessages();
  }

  Future<void> _loadTotalMessages() async {
    try {
      final snapshot = await _messagesRef.get();
      if (snapshot.value == null) {
        setState(() {
          _totalMessages = 0;
        });
        return;
      }

      final messagesMap = snapshot.value as Map<dynamic, dynamic>;
      int totalMessages = 0;

      // Count all WhatsApp messages across all dates
      messagesMap.forEach((date, dateData) {
        if (dateData is Map) {
          final dateMessages = dateData as Map<dynamic, dynamic>;
          if (dateMessages.containsKey('whatsapp') &&
              dateMessages['whatsapp'] is Map) {
            final whatsappMessages =
                dateMessages['whatsapp'] as Map<dynamic, dynamic>;
            totalMessages += whatsappMessages.length;
          }
        }
      });

      setState(() {
        _totalMessages = totalMessages;
      });
    } catch (e) {
      print('Error counting messages: $e');
      setState(() {
        _totalMessages = 0;
      });
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot =
          await _messagesRef.limitToLast((_currentPage + 1) * _pageSize).get();
      if (snapshot.value == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final messagesMap = snapshot.value as Map<dynamic, dynamic>;
      List<Message> messages = [];

      messagesMap.forEach((date, dateData) {
        if (dateData is Map) {
          final dateMessages = dateData as Map<dynamic, dynamic>;
          if (dateMessages.containsKey('whatsapp') &&
              dateMessages['whatsapp'] is Map) {
            final platformMessages =
                dateMessages['whatsapp'] as Map<dynamic, dynamic>;
            platformMessages.forEach((id, messageInfo) {
              if (messageInfo is Map) {
                final message = Message(
                  direction: messageInfo['direction']?.toString() ?? 'unknown',
                  message: messageInfo['message']?.toString() ?? '',
                  sender: messageInfo['direction'] == 'incoming'
                      ? messageInfo['sender']?.toString() ?? 'Unknown'
                      : messageInfo['receiver']?.toString() ?? 'Unknown',
                  timestamp: formatTimestamp(
                      messageInfo['timestamp']?.toString() ?? '0'),
                  messageType: messageInfo['direction'] == 'incoming'
                      ? 'Incoming'
                      : 'Outgoing',
                );
                messages.add(message);
              }
            });
          }
        }
      });

      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _messages = messages; // Changed from addAll to assignment
        _applyFilters(); // Apply filters after loading messages
        _isLoading = false;
        _currentPage++;
      });
    } catch (e, stackTrace) {
      print('Error loading messages: $e\n$stackTrace');
      setState(() {
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
    _filteredMessages = _messages.where((message) {
      bool matchesFilter = true;
      if (_selectedFilter == "incoming") {
        matchesFilter = message.direction == 'incoming';
      } else if (_selectedFilter == "outgoing") {
        matchesFilter = message.direction == 'outgoing';
      }

      if (_searchQuery.isEmpty) {
        return matchesFilter;
      }
      return matchesFilter &&
          (message.sender
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              message.message
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()));
    }).toList();
  }

  String formatTimestamp(String timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
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
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.filter_list, color: Colors.green),
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
                                ? Colors.green.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedFilter == filter
                                  ? Colors.green
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
                                    ? Colors.green
                                    : Colors.grey,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                title,
                                style: TextStyle(
                                  color: _selectedFilter == filter
                                      ? Colors.green
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
                                  color: Colors.green,
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
                  child: Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, List<Message>> _groupMessagesByDate(List<Message> messages) {
    Map<String, List<Message>> grouped = {};
    for (var message in messages) {
      final dateStr =
          DateFormat('dd MMM yyyy').format(DateTime.parse(message.timestamp));
      grouped.putIfAbsent(dateStr, () => []);
      grouped[dateStr]!.add(message);
    }
    return Map.fromEntries(grouped.entries.toList()
      ..sort((a, b) => DateFormat('dd MMM yyyy')
          .parse(b.key)
          .compareTo(DateFormat('dd MMM yyyy').parse(a.key))));
  }

  Widget _buildMessagesList() {
    if (_isLoading && _messages.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No WhatsApp messages found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No messages match your search',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    final groupedMessages = _groupMessagesByDate(_paginatedList);
    final theme = Theme.of(context);

    return ListView.builder(
      physics: BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: groupedMessages.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= groupedMessages.length) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: TextButton(
                onPressed: _loadMoreData,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.green.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Load More',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        final dateStr = groupedMessages.keys.elementAt(index);
        final messagesForDate = groupedMessages[dateStr]!;

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
                    gradient: LinearGradient(
                      colors: [Colors.green, Colors.green.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.2),
                        blurRadius: 4,
                        offset: Offset(0, 2),
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
                  '${messagesForDate.length} messages',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          content: Column(
            children: messagesForDate
                .map((message) => Card(
                      elevation: 4,
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: message.direction == 'incoming'
                          ? Colors.green.shade50
                          : Colors.blue.shade50,
                      child: ListTile(
                        contentPadding: EdgeInsets.only(
                            left: 6, right: 6, top: 6, bottom: 6),
                        leading: Container(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            message.direction == 'incoming'
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: message.direction == 'incoming'
                                ? Colors.green
                                : Colors.blue,
                          ),
                        ),
                        title: Text(
                          message.sender,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.message,
                              maxLines: 5, // Changed from no limit to 2
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: 2, horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                message.timestamp,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Full Message'),
                                content: Text(message.message),
                                actions: [
                                  TextButton(
                                    child: Text('Close'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 60),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green,
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
              "WhatsApp Messages",
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(60),
              child: Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  top: 8,
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
                            hintText: 'Search WhatsApp messages...',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                            prefixIcon: Icon(Icons.search, color: Colors.green),
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
                        tooltip: "Filter Messages",
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
              Colors.green.withOpacity(0.1),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshMessages,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (!_isLoading &&
                          scrollInfo.metrics.pixels ==
                              scrollInfo.metrics.maxScrollExtent) {
                        _loadMoreMessages();
                      }
                      return false;
                    },
                    child: _buildMessagesList(),
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

class Message {
  final String direction;
  final String message;
  final String sender;
  final String timestamp;
  final String messageType;

  Message({
    required this.direction,
    required this.message,
    required this.sender,
    required this.timestamp,
    required this.messageType,
  });
}
