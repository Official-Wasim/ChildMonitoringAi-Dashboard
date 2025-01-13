import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart'; // Added for staggered grid
import 'social_app_detail_screen.dart'; // Import the detail screen
import 'instagram_messages.dart'; // Import the Instagram messages screen

class InstantMessagingAppsScreen extends StatelessWidget {
  final List<AppInfo> apps = [
    AppInfo(
      name: "WhatsApp",
      icon: Icons.chat,
      messageCount: 12,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Instant Messaging Apps"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(), // Added for smooth scrolling
            child: StaggeredGrid.count(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: apps.map((app) {
                return StaggeredGridTile.fit(
                  crossAxisCellCount: 2,
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to the appropriate screen based on the app name
                      if (app.name == "Instagram") {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InstagramMessagesScreen(),
                          ),
                        );
                      } else if (app.name == "WhatsApp") {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MessageScreen(),
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
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: Icon(app.icon, color: app.color, size: 32),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            app.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87, // Ensured visibility
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.9), // Ensured visibility
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${app.messageCount} new messages",
                              style: TextStyle(
                                fontSize: 12,
                                color: app.color
                                    .withOpacity(0.8), // Ensured visibility
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
