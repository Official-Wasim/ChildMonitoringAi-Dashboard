import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _controller;
  bool _isInitialized = false;
  StreamSubscription? _subscription;

  Stream<bool> get onConnectivityChanged => _controller?.stream ?? Stream.value(false);

  ConnectivityService._internal();

  factory ConnectivityService() {
    return instance;
  }

  Future<void> initialize() async {
    if (!_isInitialized) {
      try {
        // Create a new controller if needed
        _controller?.close();
        _controller = StreamController<bool>.broadcast();

        // Cancel existing subscription if any
        await _subscription?.cancel();
        
        // Setup new subscription
        _subscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
          if (_controller?.isClosed == false) {
            final hasConnection = results.any((result) => result != ConnectivityResult.none);
            _controller?.add(hasConnection);
          }
        });

        // Check initial connectivity
        final results = await _connectivity.checkConnectivity();
        _checkStatus(results);
        _isInitialized = true;
      } catch (e) {
        debugPrint('Error initializing connectivity service: $e');
      }
    }
  }

  void _checkStatus(List<ConnectivityResult> results) {
    if (_controller?.isClosed == false) {
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      _controller?.add(hasConnection);
    }
  }

  Future<bool> checkConnectivity() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  static void showNoInternetPopup(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No internet connection'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _controller?.close();
    _controller = null;
    _isInitialized = false;
  }
}
