import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/instant_messaging_apps.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'package:connectivity_plus/connectivity_plus.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.max,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await setupFlutterNotifications();
  showNotification(message);
  debugPrint('Handling a background message: ${message.messageId}');
}

Future<void> initializeLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  );
}

Future<void> setupFlutterNotifications() async {
  try {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
      debugPrint('Notification channel created successfully');
    }
  } catch (e) {
    debugPrint('Error creating notification channel: $e');
  }
}

// Add this function to handle notification tap
Future<void> onNotificationTap(RemoteMessage message) async {
  if (message.data['screen'] != null) {
    NavigationService.navigatorKey.currentState?.pushNamed(message.data['screen']);
  }
}

// Add this function to handle foreground notifications
Future<void> handleForegroundMessage(RemoteMessage message) async {
  debugPrint('Got a message in foreground!');
  debugPrint('Message data: ${message.data}');

  // Always show notification in foreground
  await showNotification(message);
}

// Update showNotification to handle more cases
Future<void> showNotification(RemoteMessage message) async {
  try {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    // If notification payload is not null
    if (notification != null) {
      await flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title ?? 'New Notification',
        notification.body ?? 'You have a new message',
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_notification',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            enableLights: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  } catch (e) {
    debugPrint('Error showing notification: $e');
  }
}

// Update initializeFirebaseMessaging
Future<void> initializeFirebaseMessaging() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    
    // Request permission first
    await _requestNotificationPermissions();
    
    // Set foreground notification presentation options
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle foreground messages with immediate display
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // If `onMessage` is triggered with a notification, construct our own
      // local notification to show to users using the created channel.
      if (notification != null && android != null) {
        await flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher', // Use app icon 
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
              enableVibration: true,
              enableLights: true,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      }
    });
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification tapped in background!');
      if (message.data['screen'] != null) {
        NavigationService.navigatorKey.currentState?.pushNamed(message.data['screen']);
      }
    });
    
    // Handle notification when app is terminated
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('Notification tapped in terminated state!');
      if (initialMessage.data['screen'] != null) {
        NavigationService.navigatorKey.currentState?.pushNamed(initialMessage.data['screen']);
      }
    }

    // Get FCM token
    String? token = await messaging.getToken();
    await updateFCMToken(token);
    debugPrint('FCM Token: $token');

    // Handle token refresh
    messaging.onTokenRefresh.listen((String token) {
      updateFCMToken(token);
      debugPrint('FCM Token refreshed');
    });

  } catch (e) {
    debugPrint('Error initializing Firebase Messaging: $e');
  }
}

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

// Add this new function after NavigationService class
Future<void> updateFCMToken(String? token) async {
  if (token == null) return;
  
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('parent_fcm_token')
          .set(token);
      debugPrint('FCM token updated in database');
    }
  } catch (e) {
    debugPrint('Error updating FCM token: $e');
  }
}

// Update _requestNotificationPermissions
Future<void> _requestNotificationPermissions() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
      announcement: true,
      carPlay: true,
    );
    
    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // Request local notification permissions for iOS
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
          );
    }
  } catch (e) {
    debugPrint('Error requesting notification permissions: $e');
  }
}

// Update main function
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    
    // Initialize Connectivity plugin
    await Connectivity().checkConnectivity();
    
    // Initialize local notifications first
    await initializeLocalNotifications();
    await setupFlutterNotifications();
    
    // Then initialize Firebase Messaging
    await initializeFirebaseMessaging();
    
    // Handle notification launch
    final NotificationAppLaunchDetails? launchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      debugPrint('App launched from notification: ${launchDetails?.notificationResponse?.payload}');
    }
  } catch (e) {
    debugPrint('Error in initialization: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _requestNotificationPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AuthWrapper(),
      routes: {
        '/AuthScreen': (context) => AuthScreen(),
        '/DashboardScreen': (context) => DashboardScreen(),
        '/InstantMessagingAppsScreen': (context) =>
            InstantMessagingAppsScreen(phoneModel: 'Unknown'),
      },
    );
  }
}

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
