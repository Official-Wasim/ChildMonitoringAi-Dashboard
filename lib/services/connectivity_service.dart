import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();
  bool _isInitialized = false;

  ConnectivityService._internal();

  factory ConnectivityService() {
    return instance;
  }

  Future<void> initialize() async {
    if (!_isInitialized) {
      try {
        await _connectivity.checkConnectivity();
        _isInitialized = true;
      } catch (e) {
        debugPrint('Error initializing connectivity service: $e');
      }
    }
  }

  Future<bool> checkConnectivity() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  static void showNoInternetPopup(BuildContext context) {
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.signal_wifi_off, color: Colors.red),
                SizedBox(width: 10),
                Text('No Internet Connection'),
              ],
            ),
            content: const Text('Please check your internet connection and try again.'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }
}
