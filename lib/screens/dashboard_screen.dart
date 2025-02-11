import 'package:flutter/material.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/theme/theme.dart';
import 'instant_messaging_apps.dart';
import 'sms_history_screen.dart';
import 'call_history_screen.dart';
import 'mms_history_screen.dart';
import 'locations_screen.dart';
import 'contacts_screen.dart';
import 'apps_screen.dart';
import 'sites_screen.dart';
import 'remote_commands_screen.dart';
import 'stats_screen.dart';
import 'recents_screen.dart';
import 'settings_screeen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../models/location_info.dart';
import 'map_screen.dart';
import '../services/geocoding_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/connectivity_service.dart';
import 'dart:async'; // Add this import

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _page = 0;
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();
  String _username = 'User'; // default value
  String _selectedDevice = 'Select Device'; // Default selected device
  List<String> _devices = [
    'Select Device'
  ]; // List to store devices with default value
  static const String SELECTED_DEVICE_KEY = 'selected_device';
  bool _isLoading = false; // Set to false by default
  bool _isLoadingData = false;
  bool _isInitialLoad = true;

  // Add count variables
  Map<String, int> _counts = {
    'sms': 0,
    'mms': 0,
    'calls': 0,
    'locations': 0,
    'contacts': 0,
    'apps': 0,
    'sites': 0,
    'messages': 0,
  };

  // Updated color scheme constants
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
  static const Color textPrimaryColor = Color(0xFF1A1F36); // Dark blue-gray
  static const Color textSecondaryColor = Color(0xFF4A5568); // Medium blue-gray
  static const Color cardGradient1 = Color(0xFF3949AB); // Start gradient
  static const Color cardGradient2 = Color(0xFF1A237E); // End gradient
  static const Color statusCardBg = Color(0xFF303F9F); // Status card background

  String _currentAddress = 'Waiting for location...';
  LatLng _currentLocation = LatLng(0, 0);
  MapController _mapController = MapController(); // Add this line
  bool _hasLocationData = false;

  final ConnectivityService _connectivityService = ConnectivityService();

  // Add stream subscription variables
  StreamSubscription? _deviceDataSubscription;
  StreamSubscription? _connectivitySubscription;
  bool _disposed = false;

  // Add this method to track refresh timestamp
  Future<void> _trackRefreshRequest() async {
    try {
      _safeSetState(() {
        _isRefreshing = true;
      });

      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null && _selectedDevice != 'Select Device') {
        final DatabaseReference refreshRef = FirebaseDatabase.instance
            .reference()
            .child(
                'users/${user.uid}/phones/$_selectedDevice/on_refresh/refresh_requested');

        await refreshRef.set(ServerValue.timestamp);

        // Wait for a few seconds to allow the device to process the refresh
        await Future.delayed(const Duration(seconds: 3));
        await _fetchRefreshResults();
      }
    } catch (e) {
      debugPrint('Error tracking refresh: $e');
    } finally {
      _safeSetState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
    _loadSavedDeviceAndFetchData(); // Replace _fetchDevices() with this
    _fetchAddressWithRetry(); // Add this line
    // Add this line to fetch initial status
    _fetchRefreshResults();
  }

  @override
  void dispose() {
    _disposed = true;
    _deviceDataSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _connectivityService.dispose(); // Add this line
    super.dispose();
  }

  // Safe setState method
  void _safeSetState(VoidCallback fn) {
    if (!_disposed && mounted) {
      setState(fn);
    }
  }

  Future<void> _initializeConnectivity() async {
    await _connectivityService.initialize();
    _connectivitySubscription =
        _connectivityService.onConnectivityChanged.listen((bool hasConnection) {
      if (_disposed) return;
      if (!hasConnection && mounted) {
        ConnectivityService.showNoInternetPopup(context);
      }
    });
  }

  // Add this method near the top of the class
  Future<bool> _checkInternetConnection() async {
    bool hasInternet = await _connectivityService.checkConnectivity();
    if (!hasInternet && mounted) {
      ConnectivityService.showNoInternetPopup(context);
    }
    return hasInternet;
  }

  // Update the _loadSavedDeviceAndFetchData method
  Future<void> _loadSavedDeviceAndFetchData() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedDevice = prefs.getString(SELECTED_DEVICE_KEY);

    setState(() {
      _selectedDevice = savedDevice ?? 'Select Device';
      // Initialize devices list with the saved device if it exists
      _devices = ['Select Device'];
      if (savedDevice != null && savedDevice != 'Select Device') {
        _devices.add(savedDevice);
      }
    });

    // Fetch device data for the saved device first
    if (savedDevice != null && savedDevice != 'Select Device') {
      await _fetchDeviceData(savedDevice);
      if (_isInitialLoad) {
        await _trackRefreshRequest();
        _isInitialLoad = false;
      }
    }

    // Then fetch the complete devices list from Firebase
    await _fetchDevices();
  }

  // Fetch devices from Firebase
  Future<void> _fetchDevices() async {
    if (!mounted) return; // Add this line

    // Add internet check
    if (!await _checkInternetConnection()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DatabaseReference devicesRef = FirebaseDatabase.instance
            .reference()
            .child('users/${user.uid}/phones');

        final DatabaseEvent event = await devicesRef.once();
        if (event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);

          // Create a Set to ensure unique device names
          Set<String> uniqueDevices = {'Select Device'};
          uniqueDevices.addAll(data.keys.map((key) => key.toString()));

          // Convert Set back to List and sort
          List<String> devices = uniqueDevices.toList()..sort();

          // Make sure 'Select Device' is always first
          devices.remove('Select Device');
          devices.insert(0, 'Select Device');

          if (mounted) {
            setState(() {
              _devices = devices;

              // Only update _selectedDevice if it's not already set or if it's not in the new devices list
              if (_selectedDevice == 'Select Device' && devices.length > 1) {
                _selectedDevice = devices[1]; // Select the first actual device
                // Save this selection to SharedPreferences
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setString(SELECTED_DEVICE_KEY, _selectedDevice);
                });
              } else if (!devices.contains(_selectedDevice)) {
                _selectedDevice = 'Select Device';
                // Clear the saved device if it's no longer available
                SharedPreferences.getInstance().then((prefs) {
                  prefs.remove(SELECTED_DEVICE_KEY);
                });
              }

              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching devices: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedDevice = 'Select Device';
        });
      }
    }
  }

  // Sign out the user
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context)
          .pushReplacementNamed('/AuthScreen'); // Navigate to login screen
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  Future<void> _fetchAddress() async {
    if (!await _checkInternetConnection()) return;

    if (!_hasLocationData ||
        _currentLocation.latitude == 0 && _currentLocation.longitude == 0) {
      setState(() {
        _currentAddress = 'Location unavailable';
      });
      return;
    }

    try {
      setState(() {
        _currentAddress = 'Fetching address...';
      });

      final address = await GeocodingService.getAddressFromCoordinates(
        _currentLocation.latitude,
        _currentLocation.longitude,
      );

      if (mounted) {
        setState(() {
          _currentAddress = address.isNotEmpty ? address : 'Address not found';
        });
      }
    } catch (e) {
      debugPrint('Error fetching address: $e');
      if (mounted) {
        setState(() {
          _currentAddress = 'Error fetching address';
        });
      }
    }
  }

  Future<void> _fetchAddressWithRetry() async {
    if (!_hasLocationData) return;

    for (int i = 0; i < 3; i++) {
      try {
        await _fetchAddress();
        if (_currentAddress != 'Fetching address...' &&
            _currentAddress != 'Location unavailable' &&
            _currentAddress != 'Error fetching address') {
          break;
        }
        await Future.delayed(Duration(seconds: 2));
      } catch (e) {
        debugPrint('Retry $i failed: $e');
        if (i == 2 && mounted) {
          // On last retry
          setState(() {
            _currentAddress = 'Could not fetch address';
          });
        }
      }
    }
  }

  // Add these state variables
  bool? _isConnected;
  int? _batteryLevel;
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;
  double? _lastLocationLatitude;
  double? _lastLocationLongitude;
  double? _lastLocationAccuracy;
  DateTime? _lastLocationTimestamp;
  String? _connectionType;
  String? _connectionInfo;
  String? _chargingStatus;

  // Add this method to reset device-specific data
  void _resetDeviceData() {
    _safeSetState(() {
      _isConnected = null;
      _batteryLevel = null;
      _chargingStatus = null;
      _lastRefreshTime = null;
      _connectionType = null;
      _connectionInfo = null;
      _lastLocationLatitude = null;
      _lastLocationLongitude = null;
      _lastLocationAccuracy = null;
      _lastLocationTimestamp = null;
      _currentAddress = 'Waiting for location...';
      _hasLocationData = false;
      _currentLocation = LatLng(0, 0);
    });
  }

  // Update _fetchDeviceData method to handle device-specific data
  Future<void> _fetchDeviceData(String device) async {
    await _deviceDataSubscription?.cancel();

    if (device == 'Select Device') {
      _resetDeviceData();
      _safeSetState(() {
        _counts = {
          'sms': 0,
          'mms': 0,
          'calls': 0,
          'locations': 0,
          'contacts': 0,
          'apps': 0,
          'sites': 0,
          'messages': 0,
        };
        _username = 'User';
      });
      return;
    }

    // Add internet check
    if (!await _checkInternetConnection()) return;

    _safeSetState(() {
      _isLoadingData = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Fetch initial refresh results for the new device
        await _fetchRefreshResults();

        if (_isInitialLoad || device != _selectedDevice) {
          await _trackRefreshRequest();
          _isInitialLoad = false;
        }

        DatabaseReference deviceDataRef = FirebaseDatabase.instance
            .reference()
            .child('users/${user.uid}/phones/$device');

        // Set up stream subscription for real-time updates
        _deviceDataSubscription = deviceDataRef.onValue.listen((event) {
          if (_disposed) return;

          final data = event.snapshot.value;
          if (data == null || data is! Map) {
            _safeSetState(() {
              _isLoadingData = false;
            });
            return;
          }

          _updateDeviceData(Map<String, dynamic>.from(data));
        }, onError: (error) {
          debugPrint('Error in device data stream: $error');
          _safeSetState(() {
            _isLoadingData = false;
          });
        });
      }
    } catch (e) {
      debugPrint('Error setting up device data stream: $e');
      _safeSetState(() {
        _isLoadingData = false;
      });
    }
  }

  // Helper method to update device data
  void _updateDeviceData(Map<String, dynamic> data) {
    if (_disposed) return;

    Map<String, int> newCounts = Map.from(_counts);
    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Helper function to count current day's items
    int countTodayItems(Map dateData) {
      if (dateData[currentDate] is Map) {
        return dateData[currentDate].length;
      }
      return 0;
    }

    // Update username if available
    if (data['user-details'] != null && data['user-details']['name'] != null) {
      _username = data['user-details']['name'].toString();
    }

    // Count items for today
    if (data['sms'] is Map) newCounts['sms'] = countTodayItems(data['sms']);
    if (data['mms'] is Map) newCounts['mms'] = countTodayItems(data['mms']);
    if (data['calls'] is Map)
      newCounts['calls'] = countTodayItems(data['calls']);
    if (data['location'] is Map)
      newCounts['locations'] = countTodayItems(data['location']);
    if (data['contacts'] is Map)
      newCounts['contacts'] = data['contacts'].length;
    if (data['apps'] is Map) newCounts['apps'] = data['apps'].length;
    if (data['web_visits'] is Map)
      newCounts['sites'] = countTodayItems(data['web_visits']);

    // Count instant messages for today
    if (data['social_media_messages'] is Map &&
        data['social_media_messages'][currentDate] is Map) {
      int messageCount = 0;
      final todayMessages = data['social_media_messages'][currentDate] as Map;
      todayMessages.forEach((platform, messages) {
        if (messages is Map) {
          messageCount += messages.length;
        }
      });
      newCounts['messages'] = messageCount;
    }

    // Update location data and map preview
    if (data['location'] is Map &&
        data['location_latitude'] != null &&
        data['location_longitude'] != null) {
      final double lat = (data['location_latitude'] as num).toDouble();
      final double lng = (data['location_longitude'] as num).toDouble();

      _safeSetState(() {
        _lastLocationLatitude = lat;
        _lastLocationLongitude = lng;
        _lastLocationAccuracy =
            (data['location_accuracy'] as num?)?.toDouble() ?? 10.0;
        _lastLocationTimestamp = data['location_timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(data['location_timestamp'])
            : DateTime.now();

        _currentLocation = LatLng(lat, lng);
        _hasLocationData = true;

        // Move map to new location
        if (mounted) {
          _mapController.move(_currentLocation, 15);
          // Fetch address after location update
          _fetchAddressWithRetry();
          setState(() {});
        }
      });
    }

    _safeSetState(() {
      _counts = newCounts;
      _isLoadingData = false;
    });
  }

  // Update _updateAllData method to ensure proper order of updates
  Future<void> _updateAllData(String deviceId) async {
    if (!mounted) return;

    setState(() {
      _isLoadingData = true;
    });

    try {
      // Reset previous device data first
      _resetDeviceData();

      // Then fetch new device data
      await _fetchDeviceData(deviceId);

      // Update refresh results for new device
      await _fetchRefreshResults();

      // Trigger a refresh request for the new device
      await _trackRefreshRequest();
    } catch (e) {
      debugPrint('Error updating device data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  // Update _fetchRefreshResults to be more device-specific
  Future<void> _fetchRefreshResults() async {
    if (_selectedDevice == 'Select Device') {
      _resetDeviceData();
      return;
    }

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final refreshRef = FirebaseDatabase.instance.reference().child(
            'users/${user.uid}/phones/$_selectedDevice/on_refresh/refresh_result');

        final event = await refreshRef.once();
        if (event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          _updateDeviceStatus(data);
        }
      }
    } catch (e) {
      debugPrint('Error fetching refresh results: $e');
    }
  }

  // Add this helper method to check if device is online based on timestamp
  bool _isDeviceOnline(int? timestamp) {
    if (timestamp == null) return false;
    final lastUpdate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = DateTime.now().difference(lastUpdate);
    return difference.inMinutes <
        1; // Consider offline if last update was more than 1 minute ago
  }

  // Update the _updateDeviceStatus method
  void _updateDeviceStatus(Map<String, dynamic> data) {
    _safeSetState(() {
      // Check if device is online based on timestamp
      final timestamp = data['timestamp'] as int?;
      _isConnected = _isDeviceOnline(timestamp);

      _batteryLevel = data['batteryLevel'] as int?;
      _chargingStatus = data['chargingStatus']?.toString();
      _connectionType = data['connectionType']?.toString();
      _connectionInfo = data['connectionInfo']?.toString();
      _lastRefreshTime = DateTime.fromMillisecondsSinceEpoch(
          timestamp ?? DateTime.now().millisecondsSinceEpoch);

      // Update location data if available
      if (data['location_latitude'] != null &&
          data['location_longitude'] != null) {
        _lastLocationLatitude = (data['location_latitude'] as num?)?.toDouble();
        _lastLocationLongitude =
            (data['location_longitude'] as num?)?.toDouble();
        _lastLocationAccuracy = (data['location_accuracy'] as num?)?.toDouble();
        _lastLocationTimestamp = data['location_timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(data['location_timestamp'])
            : null;

        _currentLocation =
            LatLng(_lastLocationLatitude!, _lastLocationLongitude!);
        _hasLocationData = true;

        if (mounted) {
          _mapController.move(_currentLocation, 15);
          _fetchAddressWithRetry();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              backgroundGradientStart,
              backgroundGradientEnd,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Fixed Extended AppBar
                  Container(
                    height: screenSize.height * 0.56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primaryColor, secondaryColor],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.2),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                  ),

                  // Main Content
                  Column(
                    children: [
                      // App Bar
                      SafeArea(
                        child: AppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          title: const Text(
                            'Dashboard',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          centerTitle: true,
                          leading: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CircleAvatar(
                              radius: 15,
                              backgroundColor: Colors.white,
                              child: Text(
                                'U',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                          actions: [
                            _buildDeviceDropdown(),
                          ],
                        ),
                      ),

                      // Fixed Content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            _buildWelcomeSection(),
                            SizedBox(
                                height: screenSize.height *
                                    0.005), // Reduced from 0.01
                            _buildStatusSection(),
                            SizedBox(
                                height: screenSize.height *
                                    0.005), // Reduced from 0.01
                            _buildLocationCard(context),
                          ],
                        ),
                      ),

                      // Scrollable Dashboard Grid
                      Expanded(
                        child: Column(
                          children: [
                            SizedBox(height: 16), // Added vertical gap
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text(
                                    'Dashboard',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  Text(
                                    'See All',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Scrollable grid with existing style
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: () async {
                                  await _trackRefreshRequest();
                                  await _fetchDevices();
                                  await _fetchAddress();
                                  if (_selectedDevice != 'Select Device') {
                                    await _fetchDeviceData(_selectedDevice);
                                  }
                                },
                                child: SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: _buildDashboardGrid(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildDeviceDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        constraints: const BoxConstraints(minWidth: 120),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _devices.contains(_selectedDevice)
                ? _selectedDevice
                : 'Select Device',
            icon: const Icon(Icons.phone_android, color: Colors.white),
            dropdownColor: primaryColor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            onChanged: (String? newValue) async {
              if (newValue != null &&
                  newValue != _selectedDevice &&
                  _devices.contains(newValue)) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(SELECTED_DEVICE_KEY, newValue);
                setState(() {
                  _selectedDevice = newValue;
                });

                // Update all relevant data when device changes
                await _updateAllData(newValue);
              }
            },
            items: _devices.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value.length > 10 ? '${value.substring(0, 10)}...' : value,
                  style: TextStyle(
                    color: value == 'Select Device'
                        ? Colors.white70
                        : Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Update all data for a specific device
  Future<void> _refreshDeviceData(String deviceId) async {
    if (!mounted) return;

    setState(() {
      _isLoadingData = true;
    });

    try {
      // Reset previous device data first
      _resetDeviceData();

      // Then fetch new device data
      await _fetchDeviceData(deviceId);

      // Update refresh results for new device
      await _fetchRefreshResults();

      // Trigger a refresh request for the new device
      await _trackRefreshRequest();

      // Update location data and address
      if (_hasLocationData) {
        await _fetchAddressWithRetry();
      }
    } catch (e) {
      debugPrint('Error updating device data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  Widget _buildBottomNavigationBar() {
    return CurvedNavigationBar(
      key: _bottomNavigationKey,
      index: 0,
      items: [
        CurvedNavigationBarItem(
          child: Icon(Icons.home_outlined, color: Colors.black87),
          label: 'Home',
        ),
        CurvedNavigationBarItem(
          child: Icon(Icons.history, color: Colors.black87),
          label: 'Recent',
        ),
        CurvedNavigationBarItem(
          child: Icon(Icons.phone_android_outlined, color: Colors.black87),
          label: 'Remote',
        ),
        CurvedNavigationBarItem(
          child: Icon(Icons.bar_chart, color: Colors.black87),
          label: 'Stats',
        ),
        CurvedNavigationBarItem(
          child: Icon(Icons.settings, color: Colors.black87),
          label: 'Settings',
        ),
      ],
      color: surfaceColor,
      buttonBackgroundColor: Colors.white,
      backgroundColor: primaryColor,
      animationCurve: Curves.easeInOutCubic,
      animationDuration: const Duration(milliseconds: 800),
      onTap: (index) {
        _handleNavigation(index);
      },
      letIndexChange: (index) => true,
    );
  }

  Widget _buildWelcomeSection() {
    String? displayConnectionType;
    String? displayConnectionInfo;

    if (_connectionInfo != null) {
      final parts = _connectionInfo!.split(': ');
      if (parts.length == 2) {
        displayConnectionType = parts[0];
        displayConnectionInfo = parts[1];
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 4, vertical: 2), // Reduced vertical padding from 4
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 1), // Reduced from 2
          Text(
            _username,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2), // Reduced from 4
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_android, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      _selectedDevice,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              if (_connectionInfo != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        displayConnectionType?.toLowerCase().contains('wifi') ??
                                false
                            ? Icons.wifi
                            : Icons.signal_cellular_alt,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        displayConnectionInfo ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              Spacer(), // Add Spacer to push the next container to the right end
              if (_lastRefreshTime != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await _trackRefreshRequest();
                          await _fetchDevices();
                          await _fetchAddress();
                          if (_selectedDevice != 'Select Device') {
                            await _fetchDeviceData(_selectedDevice);
                          }
                        },
                        child: Icon(
                          Icons.refresh,
                          size: 14,
                          color: _isRefreshing ? Colors.white38 : Colors.white,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Last Update: ${DateFormat('MMM dd, HH:mm:ss').format(_lastRefreshTime!)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1.seconds),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    final screenSize = MediaQuery.of(context).size;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatusCard(
                context, Icons.signal_cellular_alt, 'Online Status'),
            SizedBox(width: screenSize.width * 0.02),
            _buildStatusCard(context, Icons.battery_6_bar, 'Battery'),
          ],
        ),
        SizedBox(height: screenSize.height * 0.008), // Reduced from 0.015
      ],
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    // Create LocationInfo instance from current location data
    final locationInfo = LocationInfo(
      latitude: _currentLocation.latitude,
      longitude: _currentLocation.longitude,
      accuracy: _lastLocationAccuracy ?? 10.0,
      timestamp: _lastLocationTimestamp ?? DateTime.now(),
      address: _currentAddress,
    );

    final screenSize = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: () {
        if (_hasLocationData) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MapScreen(
                location: LocationInfo(
                  latitude: _currentLocation.latitude,
                  longitude: _currentLocation.longitude,
                  accuracy: _lastLocationAccuracy ?? 10.0,
                  timestamp: _lastLocationTimestamp ?? DateTime.now(),
                  address: _currentAddress,
                ),
              ),
            ),
          );
        }
      },
      child: Container(
        height: screenSize.height * 0.22, // Reduced from 0.25
        padding: EdgeInsets.all(screenSize.width * 0.03), // Reduced from 0.04
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, size: 24, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Last Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _lastLocationTimestamp != null
                        ? DateFormat('MMM dd, HH:mm:ss')
                            .format(_lastLocationTimestamp!)
                        : 'No timestamp',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1.seconds),
              ],
            ),
            const SizedBox(height: 2), // Reduced from 4
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController, // Add this line
                      options: MapOptions(
                        initialCenter:
                            _hasLocationData ? _currentLocation : LatLng(0, 0),
                        initialZoom: _hasLocationData ? 15 : 2,
                        interactionOptions: const InteractionOptions(
                          enableScrollWheel: false,
                          enableMultiFingerGestureRace: false,
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.app',
                        ),
                        if (_hasLocationData) ...[
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _currentLocation,
                                width: 40,
                                height: 40,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.3),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: _currentLocation,
                                radius:
                                    (_lastLocationAccuracy ?? 100).toDouble(),
                                useRadiusInMeter: true,
                                color: Colors.blue.withOpacity(0.1),
                                borderColor: Colors.blue.withOpacity(0.3),
                                borderStrokeWidth: 2,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8), // Reduced from 12
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasLocationData
                            ? _currentAddress
                            : 'Waiting for location data...',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_hasLocationData)
                        Text(
                          '${_currentLocation.latitude.toStringAsFixed(4)}, ${_currentLocation.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_hasLocationData)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '±${_lastLocationAccuracy?.toStringAsFixed(1) ?? '10.0'}m',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12, // Increased from 6 for better spacing
      childAspectRatio: 2.1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildDashboardCard(context, Icons.sms, 'SMS', _counts['sms'] ?? 0, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SmsHistoryScreen()),
          );
        }),
        _buildDashboardCard(context, Icons.message, 'MMS', _counts['mms'] ?? 0,
            () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MmsHistoryScreen()),
          );
        }),
        _buildDashboardCard(context, Icons.call, 'Calls', _counts['calls'] ?? 0,
            () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CallHistoryScreen()),
          );
        }),
        _buildDashboardCard(
            context, Icons.location_on, 'Locations', _counts['locations'] ?? 0,
            () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LocationsScreen()),
          );
        }),
        _buildDashboardCard(
            context, Icons.contacts, 'Contacts', _counts['contacts'] ?? 0, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContactsScreen(phoneModel: _selectedDevice),
            ),
          );
        }),
        _buildDashboardCard(context, Icons.apps, 'Apps', _counts['apps'] ?? 0,
            () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AppsScreen(phoneModel: _selectedDevice)),
          );
        }),
        _buildDashboardCard(context, Icons.web, 'Sites', _counts['sites'] ?? 0,
            () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => WebVisitHistoryPage(
                      phoneModel: _selectedDevice,
                    )),
          );
        }),
        _buildDashboardCard(
          context, Icons.chat_bubble,
          'Instant\nMessaging', // Split into two lines
          _counts['messages'] ?? 0,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      InstantMessagingAppsScreen(phoneModel: _selectedDevice)),
            );
          },
          fontSize: 11, // Smaller font size for this specific card
        ),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context, IconData icon, String label) {
    final screenSize = MediaQuery.of(context).size;
    final bool isOnlineCard = label == 'Online Status';
    final bool isBatteryCard = label == 'Battery';

    String statusText = '';
    IconData statusIcon = Icons.question_mark;
    Color statusColor = Colors.white70;
    String? subtitleText;

    if (isOnlineCard && _isConnected != null) {
      statusText = _isConnected! ? 'Online' : 'Offline';
      statusIcon = _isConnected! ? Icons.check_circle : Icons.cancel;
      statusColor = _isConnected! ? Colors.green : Colors.red;
    } else if (isBatteryCard && _batteryLevel != null) {
      String chargingIndicator = '';
      bool isCharging = _chargingStatus != null &&
          _chargingStatus!.toLowerCase().contains('charging') &&
          !_chargingStatus!.toLowerCase().contains('discharging');

      if (isCharging) {
        statusIcon = Icons.battery_charging_full;
        chargingIndicator = '⚡';
      } else {
        if (_batteryLevel! > 80) {
          statusIcon = Icons.battery_full;
        } else if (_batteryLevel! > 20) {
          statusIcon = Icons.battery_5_bar;
        } else {
          statusIcon = Icons.battery_alert;
        }
      }

      statusText = '$_batteryLevel%${isCharging ? chargingIndicator : ''}';

      if (_batteryLevel! > 80) {
        statusColor = Colors.green;
      } else if (_batteryLevel! > 20) {
        statusColor = Colors.orange;
      } else {
        statusColor = Colors.red;
      }

      // Set subtitle text as charging status
      subtitleText = _chargingStatus;
    }

    return Container(
      width: screenSize.width * 0.43,
      padding: EdgeInsets.all(screenSize.width * 0.03),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 28, color: Colors.white),
              if (isBatteryCard && subtitleText != null)
                Expanded(
                  child: Text(
                    subtitleText,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (_isRefreshing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Icon(statusIcon, size: 20, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (_isRefreshing)
                ? 'Refreshing...'
                : (statusText.isNotEmpty ? statusText : label),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Add this method to handle card taps with internet check
  Future<void> _handleCardTap(VoidCallback navigationCallback) async {
    if (await _checkInternetConnection()) {
      navigationCallback();
    }
  }

  // Update _buildDashboardCard to handle loading state per card
  Widget _buildDashboardCard(BuildContext context, IconData icon, String label,
      int count, VoidCallback onTap,
      {double fontSize = 12} // Default font size is 12
      ) {
    // Get the category key from label
    final categoryKey = label.toLowerCase().replaceAll('\n', '_');

    return GestureDetector(
      onTap: () async {
        await _handleCardTap(() async {
          // Navigate first
          onTap();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cardGradient1, cardGradient2],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: cardGradient1.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.white,
              blurRadius: 0,
              spreadRadius: 0.5,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: surfaceColor,
                radius: 26,
                child: Icon(icon, size: 28, color: primaryColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _isLoadingData
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            '${_counts[categoryKey] ?? 0}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: fontSize, // Use the passed fontSize
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.1, // Reduce line height
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNavigation(index) {
    if (index == _page) return;

    setState(() => _page = index);
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          // Pass the selectedDevice to all screens
          switch (index) {
            case 0:
              return DashboardScreen();
            case 1:
              return RecentsScreen(selectedDevice: _selectedDevice);
            case 2:
              return RemoteControlScreen(selectedDevice: _selectedDevice);
            case 3:
              return AdvancedStatsScreen(selectedDevice: _selectedDevice);
            case 4:
              return SettingsScreen(selectedDevice: _selectedDevice);
            default:
              return DashboardScreen();
          }
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}
