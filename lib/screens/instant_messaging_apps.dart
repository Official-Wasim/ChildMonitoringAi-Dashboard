import 'package:flutter/material.dart';

class InstantMessagingAppsScreen extends StatelessWidget {
  final List<AppInfo> apps = [
    AppInfo(
      name: "WhatsApp",
      icon: Icons.chat,
      messageCount: 12,
      color: Colors.green,
    ),
    AppInfo(
      name: "Messenger",
      icon: Icons.message,
      messageCount: 8,
      color: Colors.blue,
    ),
    AppInfo(
      name: "Telegram",
      icon: Icons.send,
      messageCount: 5,
      color: Colors.lightBlueAccent,
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
        color: Colors.grey[50],
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: apps.length,
          itemBuilder: (context, index) {
            final app = apps[index];
            return AppCard(app: app);
          },
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final AppInfo app;

  const AppCard({Key? key, required this.app}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: app.color.withOpacity(0.2),
            child: Icon(app.icon, color: app.color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            app.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: app.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${app.messageCount} new messages",
              style: TextStyle(
                fontSize: 12,
                color: app.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
