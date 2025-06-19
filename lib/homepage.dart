import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:locallink/login.dart';
import 'package:locallink/profile.dart';
import 'package:location/location.dart';

// User model (consider moving to a separate file, e.g., models/app_user.dart)
class AppUser {
  final String id;
  final String name;
  final List<String> interests;

  AppUser({required this.id, required this.name, required this.interests});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Location and map state
  final Location _location = Location();
  LocationData? _currentPosition;
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  bool _isLoading = true;
  StreamSubscription<LocationData>?
      _locationSubscription; // For continuous updates

  // User and filtering state
  bool _isSharingLocation = true;
  List<AppUser> _nearbyUsers = [];
  List<AppUser> _filteredUsers = [];
  final List<String> _allInterests = [
    'Coffee',
    'AI',
    'Music',
    'Basketball',
    'Reading',
    'Hiking',
    'Gaming',
    'Cooking',
    'Travel'
  ];
  final Map<String, bool> _selectedInterests = {};

  @override
  void initState() {
    super.initState();
    // Initialize selected interests map
    for (var interest in _allInterests) {
      _selectedInterests[interest] = false;
    }
    _determinePosition();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel(); // Cancel the location subscription
    _mapController?.dispose(); // Dispose map controller
    super.dispose();
  }

  //
  // LOCATION METHODS
  //

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    try {
      // 1. Check if location service is enabled
      serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          setState(() => _isLoading = false);
          print("Location service not enabled after request.");
          return;
        }
      }

      // 2. Check for location permission
      permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          setState(() => _isLoading = false);
          print("Location permission denied after request.");
          return;
        }
      }

      // 3. Configure location settings for better accuracy and responsiveness
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 1000, // Update every 1 second
        distanceFilter: 10, // Update if moved by 10 meters
      );

      // Immediately set isLoading to false to show the map or "Enable location" message
      // and let the location stream update the map content.
      setState(() {
        _isLoading = false;
      });

      // 4. Get current location once to quickly populate map if possible
      _location.getLocation().then((locationData) {
        _updateLocationData(locationData);
      }).catchError((e) {
        print("Error getting initial location: $e");
      });

      // 5. Subscribe to location changes for continuous updates
      _locationSubscription =
          _location.onLocationChanged.listen((LocationData locationData) {
        _updateLocationData(locationData);
      });

      // 6. Start fetching users in parallel, as it doesn't depend on map being fully loaded
      _fetchNearbyUsers();
    } catch (e) {
      print("Error in location setup: $e");
      setState(() => _isLoading = false);
    }
  }

  void _updateLocationData(LocationData locationData) {
    if (locationData.latitude == null || locationData.longitude == null) return;

    setState(() {
      _currentPosition = locationData;

      // Update marker position or add if it doesn't exist
      _markers.removeWhere((marker) => marker.markerId.value == 'currentUser');
      _markers.add(
        Marker(
          markerId: const MarkerId('currentUser'),
          position: LatLng(locationData.latitude!, locationData.longitude!),
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });

    _animateCameraToPosition();
  }

  void _animateCameraToPosition() {
    if (_mapController != null &&
        _currentPosition != null &&
        _currentPosition!.latitude != null &&
        _currentPosition!.longitude != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentPosition!.latitude!,
              _currentPosition!.longitude!,
            ),
            zoom: 15.5,
          ),
        ),
      );
    }
  }

  //
  // USER DATA METHODS
  //

  Future<void> _fetchNearbyUsers() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    // Dummy users - replace with actual API/database call
    final dummyUsers = [
      AppUser(id: '1', name: 'Alex', interests: ['Coffee', 'AI']),
      AppUser(id: '2', name: 'Maria', interests: ['Music', 'Basketball']),
      AppUser(id: '3', name: 'Sam', interests: ['AI', 'Music']),
      AppUser(id: '4', name: 'Chloe', interests: ['Coffee', 'Reading']),
      AppUser(id: '5', name: 'David', interests: ['Basketball', 'Hiking']),
      AppUser(id: '6', name: 'Emma', interests: ['Gaming', 'Cooking']),
      AppUser(id: '7', name: 'James', interests: ['Travel', 'Hiking']),
    ];

    setState(() {
      _nearbyUsers = dummyUsers;
      _applyFilters(); // Apply filters immediately after fetching
    });
  }

  void _toggleLocationSharing(bool value) {
    setState(() {
      _isSharingLocation = value;
    });

    if (!value) {
      _locationSubscription?.pause(); // Pause location updates
      setState(() {
        _nearbyUsers.clear();
        _filteredUsers.clear();
      });
      print("Location sharing disabled.");
    } else {
      _locationSubscription?.resume(); // Resume location updates
      _fetchNearbyUsers();
      print("Location sharing enabled.");
    }
  }

  //
  // FILTER METHODS
  //

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter by Interests'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: _allInterests.map((interest) {
                    return CheckboxListTile(
                      title: Text(interest),
                      value: _selectedInterests[interest] ?? false,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          _selectedInterests[interest] = value ?? false;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Find'),
                  onPressed: () {
                    _applyFilters();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyFilters() {
    // Get list of selected interests
    final List<String> selectedInterests = _selectedInterests.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    // If no interests selected, show all users
    if (selectedInterests.isEmpty) {
      setState(() {
        _filteredUsers = _nearbyUsers;
      });
      return;
    }

    // Filter users who have at least one of the selected interests
    setState(() {
      _filteredUsers = _nearbyUsers.where((user) {
        return user.interests
            .any((interest) => selectedInterests.contains(interest));
      }).toList();
    });
  }

  //
  // UI BUILDING METHODS
  //

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _buildDrawer(), // <<< Add the Drawer here!
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFilterDialog,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.search),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title:
          const Text('VibeSync', style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 1,
      // No 'leading' property set here, so Flutter will add the drawer icon automatically
      actions: [
        const Center(
            child: Text('Share Location', style: TextStyle(fontSize: 12))),
        Switch(
          value: _isSharingLocation,
          onChanged: _toggleLocationSharing,
          activeColor: Colors.deepPurple,
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero, // Remove default ListView padding
        children: <Widget>[
          // Drawer Header
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.deepPurple,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 30,
                  child: Icon(Icons.person, color: Colors.deepPurple, size: 40),
                ),
                SizedBox(height: 10),
                Text(
                  'LocalLink User', // You can replace this with actual user's name
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Nearby Users Option
          ListTile(
            leading: const Icon(Icons.people_alt, color: Colors.deepPurple),
            title: const Text('Nearby Users', style: TextStyle(fontSize: 16)),
            onTap: () {
              // Close the drawer
              Navigator.pop(context);
              // If this is already the current screen, no further action needed
              // Otherwise, navigate back to this screen (e.g., if you had other main tabs)
            },
          ),
          // Profile Option
          ListTile(
            leading: const Icon(Icons.person, color: Colors.deepPurple),
            title: const Text('Profile', style: TextStyle(fontSize: 16)),
            onTap: () {
              // Close the drawer first
              Navigator.pop(context);
              // Navigate to ProfileScreen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
         
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.grey),
            title: const Text('Logout', style: TextStyle(fontSize: 16)),
            onTap: () {
              // Handle settings tap
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        _buildMap(),
        _buildUsersList(),
      ],
    );
  }

  Widget _buildMap() {
    // Always return GoogleMap widget, and use a default target if currentPosition is null
    // The map will then update once location is fetched.
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) => _mapController = controller,
          initialCameraPosition: CameraPosition(
            target: (_currentPosition != null &&
                    _currentPosition!.latitude != null &&
                    _currentPosition!.longitude != null)
                ? LatLng(
                    _currentPosition!.latitude!,
                    _currentPosition!.longitude!,
                  )
                : const LatLng(0, 0), // Default to (0,0) or a central location
            zoom: 15.5,
          ),
          markers: _markers,
          myLocationButtonEnabled: true, // Allow users to re-center
          myLocationEnabled: true, // Show blue dot for user's location
          zoomControlsEnabled: false,
        ),
        // Overlay a loading indicator if needed
        if (_isLoading)
          Container(
            color: Colors.white.withOpacity(0.7),
            child: const Center(child: CircularProgressIndicator()),
          ),
        // If not loading and no location, show a persistent message
        if (!_isLoading &&
            (_currentPosition == null || _currentPosition!.latitude == null))
          Positioned.fill(
            child: Container(
              color: Colors.white, // Ensure it covers the map if no location
              child: const Center(
                child: Text(
                  'Enable location to find matches!',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUsersList() {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.15,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // List of Users
              Expanded(
                child: _filteredUsers.isEmpty && !_isLoading
                    ? const Center(
                        child: Text('No one nearby matches your filters...',
                            style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _buildUserCard(user);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserCard(AppUser user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple[100],
                  child: Text(
                    user.name[0],
                    style: const TextStyle(
                        color: Colors.deepPurple, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  user.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: user.interests
                  .map((interest) => Chip(
                        label: Text(interest),
                        backgroundColor: Colors.grey[200],
                        labelStyle: const TextStyle(color: Colors.black87),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
