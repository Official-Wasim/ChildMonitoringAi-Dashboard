import 'package:flutter/material.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../services/geocoding_service.dart'; // Add this import
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/connectivity_service.dart'; // Add this import at the top with other imports

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _page = 0;
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();
  String _username = 'User'; // Changed default value
  String _selectedDevice = 'Select Device'; // Default selected device
  List<String> _devices = [
    'Select Device'
  ]; // List to store devices with default value
  static const String SELECTED_DEVICE_KEY = 'selected_device';
  bool _isLoading = false; // Set to false by default
  bool _isLoadingData = false;

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

  String _currentAddress = 'Fetching address...'; // Add this line
  final LatLng _currentLocation = LatLng(19.023964, 72.850336); // Add this line

  final ConnectivityService _connectivityService = ConnectivityService();

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
    _fetchDevices(); // Fetch devices
    _fetchAddressWithRetry(); // Add this line
  }

  Future<void> _initializeConnectivity() async {
    await _connectivityService.initialize();
  }

  // Add this method near the top of the class
  Future<bool> _checkInternetConnection() async {
    bool hasInternet = await _connectivityService.checkConnectivity();
    if (!hasInternet && mounted) {
      ConnectivityService.showNoInternetPopup(context);
    }
    return hasInternet;
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
          List<String> devices = ['Select Device', ...data.keys];

          if (mounted) {
            // Add this check
            setState(() {
              _devices = devices;
              _isLoading = false;
            });
          }

          // Load previously selected device
          final prefs = await SharedPreferences.getInstance();
          String? savedDevice = prefs.getString(SELECTED_DEVICE_KEY);
          if (savedDevice != null && devices.contains(savedDevice)) {
            if (mounted) {
              // Add this check
              setState(() {
                _selectedDevice = savedDevice;
              });
            }
            await _fetchDeviceData(savedDevice);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching devices: $e');
      if (mounted) {
        // Add this check
        setState(() {
          _isLoading = false;
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

  // Add this method
  Future<void> _fetchAddress() async {
    // Add internet check
    if (!await _checkInternetConnection()) return;

    try {
      final address = await GeocodingService.getAddressFromCoordinates(
        _currentLocation.latitude,
        _currentLocation.longitude,
      );
      if (mounted) {
        setState(() {
          _currentAddress = address;
        });
      }
    } catch (e) {
      debugPrint('Error fetching address: $e');
    }
  }

  Future<void> _fetchAddressWithRetry() async {
    for (int i = 0; i < 3; i++) {
      try {
        await _fetchAddress();
        if (_currentAddress != 'Fetching address...' &&
            _currentAddress != 'Location unavailable') {
          break;
        }
        await Future.delayed(Duration(seconds: 2));
      } catch (e) {
        debugPrint('Retry $i failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final expandedHeight = screenSize.height * 0.62;

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
              child: NestedScrollView(
                headerSliverBuilder:
                    (BuildContext context, bool innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      expandedHeight: MediaQuery.of(context).size.height * 0.56,
                      toolbarHeight: kToolbarHeight,
                      floating: false,
                      pinned: true,
                      elevation: 0,
                      flexibleSpace: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                          return Stack(
                            children: [
                              Container(
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
                              FlexibleSpaceBar(
                                background: SafeArea(
                                  child: SingleChildScrollView(
                                    physics: NeverScrollableScrollPhysics(),
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        top: kToolbarHeight,
                                        bottom: 2,
                                        left: 16,
                                        right: 16,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildWelcomeSection(),
                                          SizedBox(
                                              height: screenSize.height * 0.01),
                                          _buildStatusSection(),
                                          SizedBox(
                                              height: screenSize.height * 0),
                                          _buildLocationCard(context),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                collapseMode: CollapseMode.pin,
                              ),
                            ],
                          );
                        },
                      ),
                      backgroundColor: Colors.transparent,
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 120),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedDevice,
                                icon: const Icon(Icons.phone_android,
                                    color: Colors.white),
                                dropdownColor: primaryColor,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                onChanged: (String? newValue) async {
                                  if (newValue != null &&
                                      newValue != _selectedDevice) {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setString(
                                        SELECTED_DEVICE_KEY, newValue);
                                    setState(() {
                                      _selectedDevice = newValue;
                                    });
                                    _fetchDeviceData(newValue);
                                  }
                                },
                                items: _devices.map<DropdownMenuItem<String>>(
                                    (String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value.length > 10
                                          ? '${value.substring(0, 10)}...'
                                          : value,
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
                        ),
                      ],
                    ),
                  ];
                },
                body: RefreshIndicator(
                  onRefresh: () async {
                    await _fetchDevices();
                    await _fetchAddress();
                    if (_selectedDevice != 'Select Device') {
                      await _fetchDeviceData(_selectedDevice);
                    }
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Dashboard',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'See All',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          _buildDashboardGrid(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CurvedNavigationBar(
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
          setState(() {
            _page = index;
          });
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
                } else if (index == 4) {
                  return SettingsScreen();
                } else {
                  return DashboardScreen();
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
        letIndexChange: (index) => true,
      ),
    );
  }

  // Fetch data according to the selected device node
  Future<void> _fetchDeviceData(String device) async {
    if (device == 'Select Device') {
      if (mounted) {
        setState(() {
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
      }
      return;
    }

    // Add internet check
    if (!await _checkInternetConnection()) return;

    setState(() {
      _isLoadingData = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DatabaseReference deviceDataRef = FirebaseDatabase.instance
            .reference()
            .child('users/${user.uid}/phones/$device');

        // Fetch username from user-details
        final DatabaseEvent userDetailsEvent =
            await deviceDataRef.child('user-details/name').once();
        if (userDetailsEvent.snapshot.value != null) {
          if (mounted) {
            setState(() {
              _username = userDetailsEvent.snapshot.value.toString();
            });
          }
        }

        deviceDataRef.keepSynced(true);

        final DatabaseEvent event = await deviceDataRef.once();
        if (event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          Map<String, int> newCounts = {
            'sms': 0,
            'mms': 0,
            'calls': 0,
            'locations': 0,
            'contacts': 0,
            'apps': 0,
            'sites': 0,
            'messages': 0,
          };

          // Helper function to count items in nested date structure
          int countNestedData(Map dateData) {
            int count = 0;
            for (var dateEntries in dateData.values) {
              if (dateEntries is Map) {
                count += dateEntries.length;
              }
            }
            return count;
          }

          // Count SMS messages
          if (data['sms'] is Map) {
            newCounts['sms'] = countNestedData(data['sms']);
          }

          // Count MMS messages
          if (data['mms'] is Map) {
            newCounts['mms'] = countNestedData(data['mms']);
          }

          // Count calls
          if (data['calls'] is Map) {
            newCounts['calls'] = countNestedData(data['calls']);
          }

          // Count locations
          if (data['location'] is Map) {
            newCounts['locations'] = countNestedData(data['location']);
          }

          // Update contacts counting logic
          if (data.containsKey('contacts')) {
            try {
              final contactsData = data['contacts'];
              if (contactsData is Map) {
                newCounts['contacts'] =
                    contactsData.length; // Direct count of contacts
              }
            } catch (e) {
              debugPrint('Error counting contacts: $e');
              newCounts['contacts'] = 0;
            }
          }

          // Count apps
          if (data['apps'] is Map) {
            newCounts['apps'] = data['apps'].length;
          }

          // Count web visits
          if (data['web_visits'] is Map) {
            newCounts['sites'] = countNestedData(data['web_visits']);
          }

          // Update instant messages counting logic
          if (data['social_media_messages'] is Map) {
            int messageCount = 0;
            final messagesData = data['social_media_messages'] as Map;
            messagesData.forEach((date, platformData) {
              if (platformData is Map) {
                platformData.forEach((platform, messages) {
                  if (messages is Map) {
                    messageCount += messages.length;
                  }
                });
              }
            });
            newCounts['messages'] = messageCount;
          }

          if (mounted) {
            // Add this check
            setState(() {
              _counts = newCounts;
            });
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching device data: $e\n$stackTrace');
      // Optionally show an error message to the user
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 4, vertical: 4), // Reduced padding
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
          const SizedBox(height: 2), // Reduced spacing
          Text(
            _username,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4), // Reduced spacing
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
            _buildStatusCard(context, Icons.battery_charging_full, 'Battery'),
          ],
        ),
        SizedBox(height: screenSize.height * 0.015),
      ],
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    // Create LocationInfo instance from current location data
    final locationInfo = LocationInfo(
      latitude: _currentLocation.latitude,
      longitude: _currentLocation.longitude,
      accuracy: 10.0, // You can adjust this value based on actual accuracy data
      timestamp:
          DateTime.now(), // You can adjust this based on actual timestamp
      address: _currentAddress,
    );

    final screenSize = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MapScreen(location: locationInfo),
          ),
        );
      },
      child: Container(
        height: screenSize.height * 0.25, // Responsive height
        padding: EdgeInsets.all(screenSize.width * 0.04),
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
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    DateFormat('MMM dd, HH:mm').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: _currentLocation,
                        initialZoom: 12,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentLocation,
                              width: 30,
                              height: 30,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentAddress,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '±10.0m',
                    style: TextStyle(
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
      mainAxisSpacing: 6,
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
              Icon(icon, size: 28, color: Colors.white), // Reduced icon size
              Icon(Icons.question_mark,
                  size: 20, color: Colors.white70), // Reduced icon size
            ],
          ),
          const SizedBox(height: 8), // Reduced spacing
          Text(
            label,
            style: const TextStyle(
              fontSize: 13, // Slightly reduced font size
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
    return GestureDetector(
      onTap: () => _handleCardTap(onTap),
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
                            '$count',
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
}
