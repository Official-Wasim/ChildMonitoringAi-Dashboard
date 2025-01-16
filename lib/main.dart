import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/auth_screen.dart'; 
import 'screens/dashboard_screen.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'screens/instant_messaging_apps.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(); 
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }

  // Enable Firebase Database persistence
  FirebaseDatabase.instance.setPersistenceEnabled(true);
  FirebaseDatabase.instance
      .setPersistenceCacheSizeBytes(10000000); // 10MB cache

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Instant Messaging Apps',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Check if the user is logged in
      home: AuthWrapper(),
      routes: {
        '/AuthScreen': (context) => AuthScreen(), // Define the route
        '/DashboardScreen': (context) => DashboardScreen(),
        '/InstantMessagingAppsScreen': (context) =>
            InstantMessagingAppsScreen(), // Define the route
      },
    );
  }
}

// Wrapper widget to check authentication status
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          debugPrint('Error in authStateChanges: ${snapshot.error}');
          return Center(child: Text('Something went wrong'));
        } else if (snapshot.hasData) {
          return DashboardScreen(); // User is logged in
        } else {
          return AuthScreen(); // User is not logged in
        }
      },
    );
  }
}
