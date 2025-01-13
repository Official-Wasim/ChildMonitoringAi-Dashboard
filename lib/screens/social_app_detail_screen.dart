import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class MessageScreen extends StatefulWidget {
  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final DatabaseReference _messagesRef = FirebaseDatabase.instance.ref(
      'users/rgNHZYmejJd6D9r5nvyjSKknryA3/phones/RMX3686/social_media_messages');

  late Stream<DatabaseEvent> _messagesStream;
  List<Message> _messages = [];
  List<Message> _filteredMessages = [];
  bool _isLoading = false;
  int _pageSize = 30; // Set to 30 messages per page
  int _currentPage = 0;
  int _totalMessages = 0;
  String _searchQuery = ""; // Add search query state

  @override
  void initState() {
    super.initState();
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

    final snapshot =
        await _messagesRef.limitToLast((_currentPage + 1) * _pageSize).get();
    final messagesMap = snapshot.value as Map<dynamic, dynamic>;
    List<Message> messages = [];

    messagesMap.forEach((date, dateData) {
      final dateMessages = dateData as Map<dynamic, dynamic>;
      dateMessages.forEach((platform, platformData) {
        if (platform == 'whatsapp') {
          final platformMessages = platformData as Map<dynamic, dynamic>;
          platformMessages.forEach((id, messageInfo) {
            final message = Message(
              direction: messageInfo['direction'],
              message: messageInfo['message'],
              sender: messageInfo['direction'] == 'incoming'
                  ? messageInfo['sender']
                  : messageInfo[
                      'receiver'], // Show receiver's name for outgoing messages
              timestamp: formatTimestamp(messageInfo['timestamp']),
              messageType: messageInfo['direction'] == 'incoming'
                  ? 'Incoming'
                  : 'Outgoing',
            );
            messages.add(message);
          });
        }
      });
    });

    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      _messages.addAll(messages);
      _filteredMessages = _messages;
      _isLoading = false;
      _currentPage++;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredMessages = _messages.where((message) {
        if (_searchQuery.isEmpty) {
          return true;
        }
        return message.sender
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            message.message.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    });
  }

  String formatTimestamp(String timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text("WhatsApp Messages"),
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
                      hintText: 'Search messages...',
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
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Card(
            elevation: 4,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Messages Loaded:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${_filteredMessages.length} / $_totalMessages',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                child: ListView.builder(
                  itemCount: _filteredMessages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _filteredMessages.length) {
                      return _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : SizedBox.shrink();
                    }

                    final message = _filteredMessages[index];

                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: message.direction == 'incoming'
                          ? Colors.green.shade50
                          : Colors.blue.shade50,
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        leading: Icon(
                          message.direction == 'incoming'
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: message.direction == 'incoming'
                              ? Colors.green
                              : Colors.blue,
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
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
                            SizedBox(height: 4),
                            // Removed the message type container
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
                    );
                  },
                  physics: BouncingScrollPhysics(), // Add smooth scrolling
                ),
              ),
            ),
          ),
        ],
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
