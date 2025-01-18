import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart'; // Added for staggered grid
import 'package:firebase_database/firebase_database.dart';
import 'whatsapp_messages.dart'; // Import the detail screen
import 'instagram_messages.dart'; // Import the Instagram messages screen
import 'snapchat_messages.dart'; // Add this import
import 'package:firebase_auth/firebase_auth.dart';

class InstantMessagingAppsScreen extends StatefulWidget {
  final String phoneModel;

  const InstantMessagingAppsScreen({Key? key, required this.phoneModel})
      : super(key: key);

  @override
  _InstantMessagingAppsScreenState createState() =>
      _InstantMessagingAppsScreenState();
}

class _InstantMessagingAppsScreenState
    extends State<InstantMessagingAppsScreen> {
  late DatabaseReference _messagesRef;
  Map<String, int> messageCounts = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _messagesRef = FirebaseDatabase.instance.ref(
          'users/${user.uid}/phones/${widget.phoneModel}/social_media_messages');
    }
    _loadMessageCounts();
  }

  Future<void> _loadMessageCounts() async {
    try {
      setState(() {
        isLoading = true;
      });

      final snapshot = await _messagesRef.get();
      if (snapshot.value == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final messagesMap = snapshot.value as Map<dynamic, dynamic>;
      Map<String, int> counts = {
        'WhatsApp': 0,
        'Instagram': 0,
        'Snapchat': 0,
        'Telegram': 0,
        'Messenger': 0,
      };

      messagesMap.forEach((date, dateData) {
        if (dateData is Map) {
          final dateMessages = dateData as Map<dynamic, dynamic>;
          dateMessages.forEach((platform, messages) {
            if (messages is Map) {
              switch (platform.toString().toLowerCase()) {
                case 'whatsapp':
                  counts['WhatsApp'] =
                      (counts['WhatsApp'] ?? 0) + messages.length;
                  break;
                case 'instagram':
                  counts['Instagram'] =
                      (counts['Instagram'] ?? 0) + messages.length;
                  break;
                case 'snapchat':
                  counts['Snapchat'] =
                      (counts['Snapchat'] ?? 0) + messages.length;
                  break;
                case 'telegram':
                  counts['Telegram'] =
                      (counts['Telegram'] ?? 0) + messages.length;
                  break;
                case 'messenger':
                  counts['Messenger'] =
                      (counts['Messenger'] ?? 0) + messages.length;
                  break;
              }
            }
          });
        }
      });

      setState(() {
        messageCounts = counts;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading message counts: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Add this method to get total message count
  static int getTotalMessageCount(Map<String, int> counts) {
    return counts.values.fold(0, (sum, count) => sum + count);
  }

  final List<AppInfo> apps = [
    AppInfo(
      name: "WhatsApp",
      icon: Icons.chat,
      messageCount: 0,
      color: Colors.green,
    ),
    AppInfo(
      name: "Instagram",
      icon: Icons.camera_alt,
      messageCount: 3,
      color: Colors.pink,
    ),
    AppInfo(
      name: "Snapchat",
      icon: Icons.snapchat,
      messageCount: 1,
      color: Colors.yellow[700]!,
    ),
    AppInfo(
      name: "Telegram",
      icon: Icons.send,
      messageCount: 5,
      color: Colors.lightBlueAccent,
    ),
    AppInfo(
      name: "Messenger",
      icon: Icons.message,
      messageCount: 8,
      color: Colors.blue,
    ),
    AppInfo(
      name: "Tinder",
      icon: Icons.local_fire_department,
      messageCount: 0,
      color: Colors.red,
    ),
    AppInfo(
      name: "Bumble",
      icon: Icons.bubble_chart,
      messageCount: 0,
      color: Colors.orange,
    ),
    AppInfo(
      name: "Signal",
      icon: Icons.security,
      messageCount: 0,
      color: Colors.blueAccent,
    ),
    AppInfo(
      name: "X (Twitter)",
      icon: Icons.alternate_email,
      messageCount: 0,
      color: Colors.lightBlue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
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
              "Instant Messaging Apps",
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
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
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    physics:
                        BouncingScrollPhysics(), // Added for smooth scrolling
                    child: StaggeredGrid.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: apps.map((app) {
                        // Update message count from Firebase data
                        final count = messageCounts[app.name] ?? 0;
                        return StaggeredGridTile.fit(
                          crossAxisCellCount: 2,
                          child: GestureDetector(
                            onTap: () {
                              // Navigate to the appropriate screen based on the app name
                              if (app.name == "Instagram") {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        InstagramMessagesScreen(
                                            phoneModel: widget.phoneModel),
                                  ),
                                );
                              } else if (app.name == "WhatsApp") {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MessageScreen(
                                        phoneModel: widget.phoneModel),
                                  ),
                                );
                              } else if (app.name == "Snapchat") {
                                // Add this condition
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SnapchatMessageScreen(
                                        phoneModel: widget.phoneModel),
                                  ),
                                );
                              }
                            },
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    app.color.withOpacity(0.7),
                                    app.color.withOpacity(0.3),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: app.color.withOpacity(0.5),
                                    blurRadius: 15,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment
                                    .center, // Center align all items
                                children: [
                                  Stack(
                                    clipBehavior:
                                        Clip.none, // Allow badge to overflow
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.white,
                                        child: Icon(app.icon,
                                            color: app.color, size: 32),
                                      ),
                                      if (count > 0)
                                        Positioned(
                                          right: -8,
                                          top: -8,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: count > 99 ? 6 : 6,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: count > 99
                                                  ? BoxShape.rectangle
                                                  : BoxShape.circle,
                                              borderRadius: count > 99
                                                  ? BorderRadius.circular(12)
                                                  : null,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: Text(
                                              count > 99
                                                  ? "99+"
                                                  : count.toString(),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    app.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors
                                          .white, // Changed from Colors.black87 to Colors.white
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      count > 0
                                          ? "$count messages"
                                          : "No messages",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: app.color.withOpacity(0.8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class IndividualAppScreen extends StatelessWidget {
  final AppInfo app;

  const IndividualAppScreen({Key? key, required this.app}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(app.name),
        backgroundColor: app.color,
      ),
      body: Center(
        child: Text(
          '${app.messageCount} new messages',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

class AppInfo {
  final String name;
  final IconData icon;
  final int messageCount;
  final Color color;

  AppInfo({
    required this.name,
    required this.icon,
    required this.messageCount,
    required this.color,
  });
}

// Add this extension
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
