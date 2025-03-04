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

      // Get today's date in the format used in Firebase
      final today = DateTime.now().toIso8601String().split('T')[0];

      final snapshot = await _messagesRef.child(today).get();
      Map<String, int> counts = {
        'WhatsApp': 0,
        'Instagram': 0,
        'Snapchat': 0,
        'Telegram': 0,
        'Messenger': 0,
      };

      if (snapshot.value != null) {
        final todayMessages = snapshot.value as Map<dynamic, dynamic>;
        todayMessages.forEach((platform, messages) {
          if (messages is Map) {
            switch (platform.toString().toLowerCase()) {
              case 'whatsapp':
                counts['WhatsApp'] = messages.length;
                break;
              case 'instagram':
                counts['Instagram'] = messages.length;
                break;
              case 'snapchat':
                counts['Snapchat'] = messages.length;
                break;
              case 'telegram':
                counts['Telegram'] = messages.length;
                break;
              case 'messenger':
                counts['Messenger'] = messages.length;
                break;
            }
          }
        });
      }

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

  void _showComingSoonDialog(BuildContext context, AppInfo app) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: app.color.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: app.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    app.icon,
                    size: 40,
                    color: app.color,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "Coming Soon!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "${app.name} integration is under development",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: app.color,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      "Got it!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
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
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: StaggeredGrid.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: apps.map((app) {
                        final count = messageCounts[app.name] ?? 0;
                        return StaggeredGridTile.fit(
                          crossAxisCellCount: 2,
                          child: GestureDetector(
                            onTap: () {
                              switch (app.name) {
                                case "Instagram":
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          InstagramMessagesScreen(
                                              phoneModel: widget.phoneModel),
                                    ),
                                  );
                                  break;
                                case "WhatsApp":
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MessageScreen(
                                          phoneModel: widget.phoneModel),
                                    ),
                                  );
                                  break;
                                case "Snapchat":
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          SnapchatMessageScreen(
                                              phoneModel: widget.phoneModel),
                                    ),
                                  );
                                  break;
                                default:
                                  _showComingSoonDialog(context, app);
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    app.color.withOpacity(0.9),
                                    app.color.withOpacity(0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: app.color.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.9),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: app.color.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          app.icon,
                                          color: app.color,
                                          size: 32,
                                        ),
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
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    app.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      count > 0
                                          ? "$count messages"
                                          : "No messages",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: app.color,
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
