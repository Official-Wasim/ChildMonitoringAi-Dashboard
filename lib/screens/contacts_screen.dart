import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  _ContactsScreenState createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<ContactInfo> _contactsList = [];
  bool _isLoading = true; // Flag to show loading indicator
  String? _errorMessage; // To show an error message if data fetch fails
  String? _userId; // Variable to store the dynamic user ID
  String _searchQuery = ""; // Add search query state

  @override
  void initState() {
    super.initState();
    _getUserId();
  }

  // Fetch the current user's UID from Firebase Authentication
  Future<void> _getUserId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _userId = user.uid;
        });
        await _fetchContactsData();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not authenticated';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching user ID: $e';
      });
      debugPrint('Error fetching user ID: $e');
    }
  }

  Future<void> _fetchContactsData() async {
    final phoneModel = 'sdk_gphone64_x86_64'; // Keep the phone model hardcoded

    if (_userId == null) return; // Ensure user ID is available before fetching data

    try {
      debugPrint('Fetching data from Firebase...');
      final contactsSnapshot = await _databaseRef
          .child('users/$_userId/phones/$phoneModel/contacts')
          .get();

      if (contactsSnapshot.exists) {
        debugPrint('Data fetched successfully: ${contactsSnapshot.value}');
        final dynamic contactsData = contactsSnapshot.value;

        final List<ContactInfo> fetchedContacts = [];

        if (contactsData is Map) {
          contactsData.forEach((key, value) {
            final contactMap = Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
            fetchedContacts.add(ContactInfo(
              name: contactMap['name'] ?? 'Unknown',
              phoneNumber: contactMap['number'] ?? 'Unknown',
              date: DateTime.fromMillisecondsSinceEpoch(
                      contactMap['creationTime'] ?? 0)
                  .toString(), // Convert timestamp to a readable date
            ));
          });
        } else if (contactsData is List) {
          for (var value in contactsData) {
            if (value is Map) {
              final contactMap = Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
              fetchedContacts.add(ContactInfo(
                name: contactMap['name'] ?? 'Unknown',
                phoneNumber: contactMap['number'] ?? 'Unknown',
                date: DateTime.fromMillisecondsSinceEpoch(
                        contactMap['creationTime'] ?? 0)
                    .toString(), // Convert timestamp to a readable date
              ));
            }
          }
        }

        fetchedContacts.sort((a, b) => b.date.compareTo(a.date)); // Sort by date in descending order

        setState(() {
          _contactsList = fetchedContacts;
          _isLoading = false; // Set loading flag to false after data is fetched
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No contacts available';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching data: $e';
      });
      debugPrint('Error fetching contacts data: $e');
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  List<ContactInfo> _getFilteredContacts() {
    if (_searchQuery.isEmpty) {
      return _contactsList;
    }
    return _contactsList.where((contact) {
      return contact.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             contact.phoneNumber.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<ContactInfo> _getAllContacts() {
    return _contactsList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text("Contacts"),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Removed the text "Contacts" below the app bar
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Text(
                              _errorMessage!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        : _getFilteredContacts().isEmpty
                            ? Center(
                                child: Text(
                                  'No contacts found matching "$_searchQuery".',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                itemCount: _getFilteredContacts().length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final contact = _getFilteredContacts()[index];
                                  return ContactTile(contact: contact);
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContactInfo {
  final String name;
  final String phoneNumber;
  final String date;

  ContactInfo({
    required this.name,
    required this.phoneNumber,
    required this.date,
  });
}

class ContactTile extends StatelessWidget {
  final ContactInfo contact;
  final String formattedDate;

  ContactTile({super.key, required this.contact})
      : formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(contact.date)); // Show date and time

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.contact_phone,
              color: Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact.phoneNumber,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
