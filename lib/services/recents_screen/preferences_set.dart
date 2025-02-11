import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PreferencesService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> setAlertPreferences({
    required String userId,
    required String deviceId,
    required Map<String, bool> preferences,
  }) async {
    try {
      final preferencesRef = _database
          .child('users')
          .child(userId)
          .child('phones')
          .child(deviceId)
          .child('preferences');

      await preferencesRef.set({
        'new_app_install': preferences['new_app_install'] ?? false,
        'screen_time_limit': preferences['screen_time_limit'] ?? false,
        'geofence': preferences['geofence'] ?? false,
        'suspicious_content': preferences['suspicious_content'] ?? false,
        'late_night_activity': preferences['late_night_activity'] ?? false,
        'blocked_website': preferences['blocked_website'] ?? false,
        'suspicious_search': preferences['suspicious_search'] ?? false,
      });
    } catch (e) {
      throw Exception('Failed to set alert preferences: $e');
    }
  }

  static Future<Map<String, bool>> getAlertPreferences({
    required String deviceId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user signed in');
      }

      final preferencesRef = _database
          .child('users')
          .child(currentUser.uid)
          .child('phones')
          .child(deviceId)
          .child('preferences');

      final snapshot = await preferencesRef.get();

      if (!snapshot.exists) {
        final defaultPreferences = {
          'new_app_install': false,
          'screen_time_limit': false,
          'geofence': false,
          'suspicious_content': false,
          'late_night_activity': false,
          'blocked_website': false,
          'suspicious_search': false,
        };
        await preferencesRef.set(defaultPreferences);
        return defaultPreferences;
      }

      // Properly convert the data to Map<String, bool>
      final data = snapshot.value as Map<dynamic, dynamic>;
      return {
        'new_app_install': _toBool(data['new_app_install']),
        'screen_time_limit': _toBool(data['screen_time_limit']),
        'geofence': _toBool(data['geofence']),
        'suspicious_content': _toBool(data['suspicious_content']),
        'late_night_activity': _toBool(data['late_night_activity']),
        'blocked_website': _toBool(data['blocked_website']),
        'suspicious_search': _toBool(data['suspicious_search']),
      };
    } catch (e) {
      throw Exception('Failed to get alert preferences: $e');
    }
  }

  // Add this helper method to safely convert values to bool
  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  static Future<void> updateSinglePreference({
    required String deviceId,
    required String preference,
    required bool value,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user signed in');
      }

      final preferenceRef = _database
          .child('users')
          .child(currentUser.uid)
          .child('phones')
          .child(deviceId)
          .child('preferences')
          .child(preference);

      await preferenceRef.set(value);
    } catch (e) {
      throw Exception('Failed to update preference: $e');
    }
  }

  static Future<Map<String, List<String>>> getWebAlerts(String deviceId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      final alertsRef = _database
          .child('users')
          .child(currentUser.uid)
          .child('phones')
          .child(deviceId)
          .child('preferences')
          .child('web_flagged');

      final snapshot = await alertsRef.get();

      if (!snapshot.exists) {
        final defaultAlerts = {
          'keywords': <String>[],
          'urls': <String>[],
        };
        await alertsRef.set(defaultAlerts);
        return defaultAlerts;
      }

      final data = snapshot.value as Map;
      return {
        'keywords': List<String>.from(data['keywords'] ?? []),
        'urls': List<String>.from(data['urls'] ?? []),
      };
    } catch (e) {
      throw Exception('Failed to get web alerts: $e');
    }
  }

  static Future<void> addWebAlert({
    required String deviceId,
    required String type,
    required String value,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      final alertsRef = _database
          .child('users')
          .child(currentUser.uid)
          .child('phones')
          .child(deviceId)
          .child('preferences')
          .child('web_flagged')
          .child(type);

      final snapshot = await alertsRef.get();
      final List<String> currentAlerts =
          List<String>.from((snapshot.value as List?) ?? []);

      if (!currentAlerts.contains(value)) {
        currentAlerts.add(value);
        await alertsRef.set(currentAlerts);
      }
    } catch (e) {
      throw Exception('Failed to add web alert: $e');
    }
  }

  static Future<void> removeWebAlert({
    required String deviceId,
    required String type,
    required String value,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      final alertsRef = _database
          .child('users')
          .child(currentUser.uid)
          .child('phones')
          .child(deviceId)
          .child('preferences')
          .child('web_flagged')
          .child(type);

      final snapshot = await alertsRef.get();
      final List<String> currentAlerts =
          List<String>.from((snapshot.value as List?) ?? []);

      currentAlerts.remove(value);
      await alertsRef.set(currentAlerts);
    } catch (e) {
      throw Exception('Failed to remove web alert: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAppLimits(
      String deviceId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      final limitsRef = _database
          .child('users')
          .child(currentUser.uid)
          .child('phones')
          .child(deviceId)
          .child('preferences')
          .child('app_limits');

      final snapshot = await limitsRef.get();

      if (!snapshot.exists) {
        return [];
      }

      final data = snapshot.value as List<dynamic>;
      return List<Map<String, dynamic>>.from(
          data.map((item) => Map<String, dynamic>.from(item)));
    } catch (e) {
      throw Exception('Failed to get app limits: $e');
    }
  }

  static Future<bool> checkAppExistence(
    String deviceId,
    String identifier,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      final appsRef = _database
          .child('users')
          .child(currentUser.uid)
          .child('phones')
          .child(deviceId)
          .child('apps');

      // First try exact package name match
      final packageSnapshot = await appsRef.child(identifier).get();
      if (packageSnapshot.exists) {
        final appData = packageSnapshot.value as Map<dynamic, dynamic>;
        if (appData['status'] == 'installed') {
          return true;
        }
      }

      // If not found by package name, try searching by app name
      final allAppsSnapshot = await appsRef.get();
      if (!allAppsSnapshot.exists) return false;

      final allApps = allAppsSnapshot.value as Map<dynamic, dynamic>;
      return allApps.entries.any((entry) {
        final app = entry.value as Map<dynamic, dynamic>;
        return app['appName']?.toString().toLowerCase() ==
                identifier.toLowerCase() &&
            app['status'] == 'installed';
      });
    } catch (e) {
      throw Exception('Failed to check app existence: $e');
    }
  }

  static Future<void> addAppLimit({
    required String deviceId,
    required String appName,
    required int hours,
    required int minutes,
    required String packageName,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      // Check if app exists and is installed
      final bool appExists = await checkAppExistence(deviceId, packageName);
      if (!appExists) {
        throw Exception('App is not installed on the device');
      }

      final limitsRef = _database
          .child('users')
          .child(currentUser.uid)
          .child('phones')
          .child(deviceId)
          .child('preferences')
          .child('app_limits');

      final snapshot = await limitsRef.get();
      final List<Map<String, dynamic>> currentLimits = snapshot.exists
          ? List<Map<String, dynamic>>.from((snapshot.value as List)
              .map((item) => Map<String, dynamic>.from(item)))
          : [];

      final existingIndex = currentLimits
          .indexWhere((limit) => limit['packageName'] == packageName);

      final newLimit = {
        'appName': appName,
        'packageName': packageName,
        'hours': hours,
        'minutes': minutes,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      if (existingIndex >= 0) {
        currentLimits[existingIndex] = newLimit;
      } else {
        currentLimits.add(newLimit);
      }

      await limitsRef.set(currentLimits);
    } catch (e) {
      throw Exception('Failed to add app limit: $e');
    }
  }

  static Future<void> removeAppLimit({
    required String deviceId,
    required String appName,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      final limitsRef = _database
          .child('users')
          .child(currentUser.uid)
          .child('phones')
          .child(deviceId)
          .child('preferences')
          .child('app_limits');

      final snapshot = await limitsRef.get();
      if (!snapshot.exists) return;

      final List<Map<String, dynamic>> currentLimits =
          List<Map<String, dynamic>>.from((snapshot.value as List)
              .map((item) => Map<String, dynamic>.from(item)));

      currentLimits.removeWhere((limit) => limit['appName'] == appName);
      await limitsRef.set(currentLimits);
    } catch (e) {
      throw Exception('Failed to remove app limit: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getGeofences(
      String deviceId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      final geofencesRef = _database
          .child('users')
          .child(currentUser.uid)
          .child('phones')
          .child(deviceId)
          .child('preferences')
          .child('geofences');

      final snapshot = await geofencesRef.get();

      if (!snapshot.exists) {
        return [];
      }

      final data = snapshot.value as List<dynamic>;
      return List<Map<String, dynamic>>.from(
          data.map((item) => Map<String, dynamic>.from(item)));
    } catch (e) {
      throw Exception('Failed to get geofences: $e');
    }
  }

  static Future<void> addGeofence({
    required String deviceId,
    required String name,
    required double latitude,
    required double longitude,
    required int radius,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      final geofencesRef = _database
          .child('users')
          .child(currentUser.uid)
          .child('phones')
          .child(deviceId)
          .child('preferences')
          .child('geofences');

      final snapshot = await geofencesRef.get();
      final List<Map<String, dynamic>> currentFences = snapshot.exists
          ? List<Map<String, dynamic>>.from((snapshot.value as List)
              .map((item) => Map<String, dynamic>.from(item)))
          : [];

      final newFence = {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final existingIndex =
          currentFences.indexWhere((fence) => fence['name'] == name);

      if (existingIndex >= 0) {
        currentFences[existingIndex] = newFence;
      } else {
        currentFences.add(newFence);
      }

      await geofencesRef.set(currentFences);
    } catch (e) {
      throw Exception('Failed to add geofence: $e');
    }
  }

  static Future<void> removeGeofence({
    required String deviceId,
    required String name,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      final geofencesRef = _database
          .child('users')
          .child(currentUser.uid)
          .child('phones')
          .child(deviceId)
          .child('preferences')
          .child('geofences');

      final snapshot = await geofencesRef.get();
      if (!snapshot.exists) return;

      final List<Map<String, dynamic>> currentFences =
          List<Map<String, dynamic>>.from((snapshot.value as List)
              .map((item) => Map<String, dynamic>.from(item)));

      currentFences.removeWhere((fence) => fence['name'] == name);
      await geofencesRef.set(currentFences);
    } catch (e) {
      throw Exception('Failed to remove geofence: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getInstalledAppSuggestions(
    String deviceId,
    String searchQuery,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      final appsRef = _database
          .child('users')
          .child(currentUser.uid)
          .child('phones')
          .child(deviceId)
          .child('apps');

      final snapshot = await appsRef.get();
      if (!snapshot.exists) return [];

      final allApps = snapshot.value as Map<dynamic, dynamic>;
      final suggestions = allApps.entries
          .where((entry) {
            final app = entry.value as Map<dynamic, dynamic>;
            return app['status'] == 'installed' &&
                app['appName']
                    .toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase());
          })
          .map((entry) => {
                'appName': (entry.value as Map)['appName'],
                'packageName': entry.key,
              })
          .toList();

      return suggestions;
    } catch (e) {
      throw Exception('Failed to get app suggestions: $e');
    }
  }

  // Fetch keyword alerts
  static Future<List<String>> getKeywordAlerts(String deviceId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users/$uid/phones/$deviceId/preferences/keyword_alerts')
          .get();

      if (!snapshot.exists) return [];

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return data.keys.toList();
    } catch (e) {
      print('Error fetching keyword alerts: $e');
      return [];
    }
  }

  // Add a new keyword alert
  static Future<void> addKeywordAlert({
    required String deviceId,
    required String keyword,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      if (keyword.trim().isEmpty) {
        throw Exception('Keyword cannot be empty');
      }

      // Create a sanitized key from the keyword
      final keywordKey = keyword.toLowerCase().trim().replaceAll(' ', '_');

      await FirebaseDatabase.instance
          .ref()
          .child('users/$uid/phones/$deviceId/preferences/keyword_alerts')
          .child(keywordKey)
          .set({
        'keyword': keyword.trim(),
        'created_at': ServerValue.timestamp,
        'enabled': true,
      });
    } catch (e) {
      print('Error adding keyword alert: $e');
      throw Exception('Failed to add keyword alert: $e');
    }
  }

  // Remove a keyword alert
  static Future<void> removeKeywordAlert({
    required String deviceId,
    required String keyword,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      // Create a sanitized key from the keyword
      final keywordKey = keyword.toLowerCase().trim().replaceAll(' ', '_');

      await FirebaseDatabase.instance
          .ref()
          .child('users/$uid/phones/$deviceId/preferences/keyword_alerts')
          .child(keywordKey)
          .remove();
    } catch (e) {
      print('Error removing keyword alert: $e');
      throw Exception('Failed to remove keyword alert: $e');
    }
  }
}
