import 'package:flutter/material.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:firebase_database/firebase_database.dart'; // Import FirebaseDatabase
import 'package:shared_preferences/shared_preferences.dart';
import 'instant_messaging_apps.dart';
import 'sms_history_screen.dart';
import 'call_history_screen.dart';
import 'mms_history_screen.dart';
import 'locations_screen.dart';
import 'contacts_screen.dart';
import 'apps_screen.dart';
import 'sites_screen.dart';
import 'remote_commands_screen.dart'; // Import RemoteControlScreen

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _page = 0;
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();
  String _username = 'Username'; // Default username
  String _selectedDevice = 'Select Device'; // Default selected device
  List<String> _devices = [
    'Select Device'
  ]; // List to store devices with default value
  static const String SELECTED_DEVICE_KEY = 'selected_device';
  bool _isLoading = true; // Add this line at the top with other variables

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

  @override
  void initState() {
    super.initState();
    _fetchUsername(); // Fetch dynamic username
    _fetchDevices(); // Fetch devices
  }

  // Fetch username from FirebaseAuth
  Future<void> _fetchUsername() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _username =
              user.displayName ?? 'User'; // Use displayName if available
        });
      } else {
        // No user is signed in
      }
    } catch (e) {
      // Error fetching username
    }
  }

  // Fetch devices from Firebase Realtime Database
  Future<void> _fetchDevices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DatabaseReference devicesRef = FirebaseDatabase.instance
            .reference()
            .child('users/${user.uid}/phones');

        // Enable data persistence
        FirebaseDatabase.instance.setPersistenceEnabled(true);
        devicesRef.keepSynced(true);

        final snapshot = await devicesRef.get();
        if (snapshot.value != null) {
          Map<dynamic, dynamic> devicesMap =
              snapshot.value as Map<dynamic, dynamic>;
          List<String> devicesList = devicesMap.keys.toList().cast<String>();

          // Get previously selected device from SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          String? savedDevice = prefs.getString(SELECTED_DEVICE_KEY);

          setState(() {
            _devices = devicesList;
            if (savedDevice != null && _devices.contains(savedDevice)) {
              _selectedDevice = savedDevice;
            } else if (_devices.isNotEmpty) {
              _selectedDevice = _devices[0];
              // Save the first device as selected
              prefs.setString(SELECTED_DEVICE_KEY, _selectedDevice);
            }
          });

          // Fetch data for the selected device
          if (_selectedDevice != 'Select Device') {
            await _fetchDeviceData(_selectedDevice);
          }
        }
      }
    } catch (e) {
      // Error fetching devices
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
            kToolbarHeight + 10), // Adjusted to be a little more than content
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: Padding(
              padding:
                  const EdgeInsets.all(8.0), // Add padding to adjust the avatar
              child: CircleAvatar(
                radius: 15, // Make the avatar smaller
                backgroundColor: Colors.white,
                child: Text(
                  _username.isNotEmpty
                      ? _username[0]
                      : 'U', // Check if _username is not empty
                  style: TextStyle(
                    fontSize: 16, // Adjust font size accordingly
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ),
            title: const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white, // Change text color to white
              ),
            ),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 120),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDevice,
                          icon: const Icon(Icons.phone_android,
                              color: Colors.white),
                          dropdownColor: Colors.blueAccent,
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
                          items: _devices
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                // Truncate text if longer than 10 characters
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.white,
      bottomNavigationBar: CurvedNavigationBar(
        key: _bottomNavigationKey,
        index: 0,
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
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 600),
        onTap: (index) {
          setState(() {
            _page = index;
          });
          if (index == 2) {
            // Check if 'Remote Control' is selected
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const RemoteControlScreen()),
            );
          }
        },
        letIndexChange: (index) => true,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading dashboard...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                // Refresh data when pulled down
                await _fetchDevices();
                if (_selectedDevice != 'Select Device') {
                  await _fetchDeviceData(_selectedDevice);
                }
              },
              child: Center(
                child: SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(), // Enable scrolling even when content fits
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: 800, // Limit maximum width for better layout
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _username, // Display dynamic username
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.phone_android, size: 16),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _selectedDevice,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatusCard(context, Icons.signal_cellular_alt,
                                'Online Status'),
                            _buildStatusCard(context,
                                Icons.battery_charging_full, 'Battery'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildLocationCard(context),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Dashboard',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'See All',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.9,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildDashboardCard(
                                context, Icons.sms, 'SMS', _counts['sms'] ?? 0,
                                () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const SmsHistoryScreen()),
                              );
                            }),
                            _buildDashboardCard(context, Icons.message, 'MMS',
                                _counts['mms'] ?? 0, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const MmsHistoryScreen()),
                              );
                            }),
                            _buildDashboardCard(context, Icons.call, 'Calls',
                                _counts['calls'] ?? 0, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const CallHistoryScreen()),
                              );
                            }),
                            _buildDashboardCard(context, Icons.location_on,
                                'Locations', _counts['locations'] ?? 0, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const LocationsScreen()),
                              );
                            }),
                            _buildDashboardCard(context, Icons.contacts,
                                'Contacts', _counts['contacts'] ?? 0, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ContactsScreen(
                                        phoneModel:
                                            _selectedDevice)), // Pass selected device
                              );
                            }),
                            _buildDashboardCard(context, Icons.apps, 'Apps',
                                _counts['apps'] ?? 0, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AppsScreen(
                                        phoneModel: _selectedDevice)),
                              );
                            }),
                            _buildDashboardCard(context, Icons.web, 'Sites',
                                _counts['sites'] ?? 0, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => WebVisitHistoryPage(
                                          phoneModel: '',
                                        )),
                              );
                            }),
                            _buildDashboardCard(
                                context,
                                Icons.chat_bubble,
                                '        Instant\n Messaging',
                                _counts['messages'] ?? 0, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        InstantMessagingAppsScreen()),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // Fetch data according to the selected device node
  Future<void> _fetchDeviceData(String device) async {
    if (device == 'Select Device') {
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
      });
      return;
    }

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DatabaseReference deviceDataRef = FirebaseDatabase.instance
            .reference()
            .child('users/${user.uid}/phones/$device');

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
                // Count only valid contact entries
                int validContacts = 0;
                contactsData.forEach((key, value) {
                  if (value is Map &&
                      value.containsKey('name') &&
                      value.containsKey('phoneNumber')) {
                    validContacts++;
                  }
                });
                newCounts['contacts'] = validContacts;
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

          // Count instant messages
          if (data['messages'] is Map) {
            int messageCount = 0;
            final messagesData = data['messages'] as Map;
            for (var app in messagesData.values) {
              if (app is Map) {
                for (var chat in app.values) {
                  if (chat is Map) {
                    messageCount += chat.length;
                  }
                }
              }
            }
            newCounts['messages'] = messageCount;
          }

          setState(() {
            _counts = newCounts;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching device data: $e\n$stackTrace');
      // Optionally show an error message to the user
    }
  }

  Widget _buildStatusCard(BuildContext context, IconData icon, String label) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.45,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: Icon(Icons.question_mark,
                          size: 36, color: Colors.blue),
                    ),
                    Icon(icon, size: 36, color: Colors.blue),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(Icons.location_on, size: 36, color: Colors.blue),
                  const SizedBox(height: 6),
                  const Text(
                    'Location',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last Location',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Lorem Ipsum is simply dummy text of the printing and typesetting industry. '
                      'Lorem Ipsum has been the industry\'s standard dummy text ever since the 1500s.',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
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

  Widget _buildDashboardCard(BuildContext context, IconData icon, String label,
      int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(1),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 26,
                child: Icon(icon, size: 32, color: Colors.blueAccent),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.contain,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$count',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                    ),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 22,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
