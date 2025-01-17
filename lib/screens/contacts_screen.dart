import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:sticky_headers/sticky_headers/widget.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart'; // Add this import

class ContactsScreen extends StatefulWidget {
  final String phoneModel; // Add this line

  ContactsScreen({required this.phoneModel}); // Modify constructor

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
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false); // Add this line

  static const int _itemsPerPage = 50;
  int _currentPage = 0;
  bool _hasMoreData = true;

  List<ContactInfo> get _paginatedContacts {
    final startIndex = 0;
    final endIndex = (_currentPage + 1) * _itemsPerPage;
    if (startIndex >= _getFilteredContacts().length) return [];
    return _getFilteredContacts()
        .sublist(startIndex, endIndex.clamp(0, _getFilteredContacts().length));
  }

  void _loadMoreData() {
    setState(() {
      _currentPage++;
      _hasMoreData =
          (_currentPage + 1) * _itemsPerPage < _getFilteredContacts().length;
    });
  }

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
    }
  }

  Future<void> _fetchContactsData({bool isRefresh = false}) async {
    if (_userId == null)
      return; // Ensure user ID is available before fetching data

    try {
      final contactsSnapshot = await _databaseRef
          .child(
              'users/$_userId/phones/${widget.phoneModel}/contacts') // Use widget.phoneModel
          .get();

      if (contactsSnapshot.exists) {
        final dynamic contactsData = contactsSnapshot.value;

        final List<ContactInfo> fetchedContacts = [];

        if (contactsData is Map) {
          contactsData.forEach((key, value) {
            if (value is Map) {
              final contactMap = Map<String, dynamic>.from(value);

              // Check for both 'number' and 'phoneNumber' keys
              final phoneNumber = contactMap['phoneNumber'] ??
                  contactMap['number'] ??
                  contactMap['phone'] ??
                  'Unknown';

              fetchedContacts.add(ContactInfo(
                name: contactMap['name'] ?? 'Unknown',
                phoneNumber: phoneNumber,
                date: DateTime.fromMillisecondsSinceEpoch(
                        contactMap['creationTime'] ?? 0)
                    .toString(),
              ));
            }
          });
        } else if (contactsData is List) {
          for (var value in contactsData) {
            if (value is Map) {
              final contactMap = Map<String, dynamic>.from(value);

              // Check for both 'number' and 'phoneNumber' keys
              final phoneNumber = contactMap['phoneNumber'] ??
                  contactMap['number'] ??
                  contactMap['phone'] ??
                  'Unknown';

              fetchedContacts.add(ContactInfo(
                name: contactMap['name'] ?? 'Unknown',
                phoneNumber: phoneNumber,
                date: DateTime.fromMillisecondsSinceEpoch(
                        contactMap['creationTime'] ?? 0)
                    .toString(),
              ));
            }
          }
        }

        fetchedContacts.sort((a, b) =>
            b.date.compareTo(a.date)); // Sort by date in descending order

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
    }
    if (isRefresh) {
      _refreshController.refreshCompleted();
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
          contact.phoneNumber
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<ContactInfo> _getAllContacts() {
    return _contactsList;
  }

  Map<String, List<ContactInfo>> _groupContactsByDate(
      List<ContactInfo> contacts) {
    Map<String, List<ContactInfo>> grouped = {};
    for (var contact in contacts) {
      final dateStr =
          DateFormat('dd MMM yyyy').format(DateTime.parse(contact.date));
      grouped.putIfAbsent(dateStr, () => []);
      grouped[dateStr]!.add(contact);
    }
    return Map.fromEntries(grouped.entries.toList()
      ..sort((a, b) => DateFormat('dd MMM yyyy')
          .parse(b.key)
          .compareTo(DateFormat('dd MMM yyyy').parse(a.key))));
  }

  Widget _buildContactsList() {
    final groupedContacts = _groupContactsByDate(_paginatedContacts);
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: groupedContacts.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= groupedContacts.length) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: TextButton(
                onPressed: _loadMoreData,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Load More',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        final dateStr = groupedContacts.keys.elementAt(index);
        final contactsForDate = groupedContacts[dateStr]!;

        return StickyHeader(
          header: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue,
                        Colors.blue.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    dateStr,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${contactsForDate.length} contacts',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Add this
              children: contactsForDate
                  .map((contact) => ContactTile(contact: contact))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(160),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
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
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              "Contacts",
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(100),
              child: Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 30,
                  top: 12,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: _onSearchChanged,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search contacts...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      prefixIcon: Icon(Icons.search,
                          color: Colors
                              .blue), // Change the search icon color to Colors.blue
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
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
              Colors.blue.withOpacity(0.1),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _getFilteredContacts().isEmpty
                        ? Center(
                            child: Text(
                              'No contacts found matching "$_searchQuery".',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        : SmartRefresher(
                            controller: _refreshController,
                            enablePullDown: true,
                            onRefresh: () =>
                                _fetchContactsData(isRefresh: true),
                            child: _buildContactsList(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
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
      : formattedDate = DateFormat('yyyy-MM-dd HH:mm')
            .format(DateTime.parse(contact.date)); // Show date and time

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8), // Add bottom margin
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
