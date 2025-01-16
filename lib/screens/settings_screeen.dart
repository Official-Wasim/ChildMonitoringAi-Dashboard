import 'package:flutter/material.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import 'dashboard_screen.dart';
import 'recents_screen.dart';
import 'remote_commands_screen.dart';
import 'stats_screen.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Center(
        child: Text('Settings Screen Content'),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: 4, // Settings tab
        items: [
          CurvedNavigationBarItem(
            child: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          CurvedNavigationBarItem(
            child: Icon(Icons.history),
            label: 'Recent',
          ),
          CurvedNavigationBarItem(
            child: Icon(Icons.phone_android_outlined),
            label: 'Remote',
          ),
          CurvedNavigationBarItem(
            child: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          CurvedNavigationBarItem(
            child: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        color: Colors.white,
        buttonBackgroundColor: Colors.white,
        backgroundColor: Colors.blueAccent,
        animationCurve: Curves.easeInOutCubic,
        animationDuration: const Duration(milliseconds: 800),
        onTap: (index) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                if (index == 0) {
                  return DashboardScreen();
                } else if (index == 1) {
                  return RecentsScreen();
                } else if (index == 2) {
                  return const RemoteControlScreen();
                } else if (index == 3) {
                  return const AdvancedStatsScreen();
                } else {
                  return SettingsScreen();
                }
              },
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOutCubic;

                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));

                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
