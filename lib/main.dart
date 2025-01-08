import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/auth_screen.dart'; // Import the login screen
import 'screens/dashboard_screen.dart'; // Import the dashboard screen
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:url_launcher/url_launcher.dart'; // Add this import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Firebase Login App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Check if the user is logged in
      home: AuthWrapper(),
      routes: {
        '/AuthScreen': (context) => AuthScreen(), // Define the route
        '/DashboardScreen': (context) => DashboardScreen(),
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
