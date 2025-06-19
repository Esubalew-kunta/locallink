import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

// User model
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
  
  // User and filtering state
  bool _isSharingLocation = true;
  List<AppUser> _nearbyUsers = [];
  List<AppUser> _filteredUsers = [];
  final List<String> _allInterests = [
    'Coffee', 'AI', 'Music', 'Basketball', 'Reading', 
    'Hiking', 'Gaming', 'Cooking', 'Travel'
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

  //
  // LOCATION METHODS
  //
  
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // Check if location service is enabled
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }
    }

    // Check for location permission
    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        setState(() => _isLoading = false);
        return;
      }
    }

    // Get current location
    try {
      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _currentPosition = locationData;
          _markers.add(
            Marker(
              markerId: const MarkerId('currentUser'),
              position: LatLng(locationData.latitude!, locationData.longitude!),
              infoWindow: const InfoWindow(title: 'Your Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          );
          _isLoading = false;
        });

        _animateCameraToPosition();
        _fetchNearbyUsers();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error getting location: $e");
      setState(() => _isLoading = false);
    }
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
      _filteredUsers = dummyUsers;
    });
  }

  void _toggleLocationSharing(bool value) {
    setState(() {
      _isSharingLocation = value;
    });

    if (!value) {
      setState(() {
        _nearbyUsers.clear();
        _filteredUsers.clear();
      });
    } else {
      _fetchNearbyUsers();
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
        return user.interests.any((interest) => selectedInterests.contains(interest));
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
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFilterDialog,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.search),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('VibeSync',
          style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 1,
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

  Widget _buildBody() {
    return Stack(
      children: [
        _buildMap(),
        _buildUsersList(),
      ],
    );
  }
Widget _buildMap() {
  return Stack(
    children: [
      // Always initialize Google Maps, even before we have a position
      GoogleMap(
        onMapCreated: (controller) => _mapController = controller,
        initialCameraPosition: CameraPosition(
          // Use a default position or last saved position if available
          target: _currentPosition != null && 
                  _currentPosition!.latitude != null && 
                  _currentPosition!.longitude != null
              ? LatLng(_currentPosition!.latitude!, _currentPosition!.longitude!)
              : const LatLng(0, 0), // Default position (will be updated)
          zoom: 15.5,
        ),
        markers: _markers,
        myLocationButtonEnabled: false, // Allow users to find themselves
        
        myLocationEnabled: true, // Show blue dot
        zoomControlsEnabled: false,
      ),
      
      // Only show loading indicator if we're still waiting
      if (_isLoading)
        Container(
          color: Colors.white.withOpacity(0.7),
          child: const Center(child: CircularProgressIndicator()),
        ),
    ],
  );
}
  // Widget _buildMap() {
  //   if (_currentPosition != null &&
  //       _currentPosition!.latitude != null &&
  //       _currentPosition!.longitude != null) {
  //     return GoogleMap(
  //       onMapCreated: (controller) => _mapController = controller,
  //       initialCameraPosition: CameraPosition(
  //         target: LatLng(_currentPosition!.latitude!,
  //             _currentPosition!.longitude!),
  //         zoom: 15.5,
  //       ),
  //       markers: _markers,
  //       myLocationButtonEnabled: false,
  //       zoomControlsEnabled: false,
  //     );
  //   } else if (_isLoading) {
  //     return const Center(child: CircularProgressIndicator());
  //   } else {
  //     return const Center(child: Text('Enable location to find matches!'));
  //   }
  // }

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
              BoxShadow(
                  color: Colors.black.withOpacity(0.2), blurRadius: 10),
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
                child: _filteredUsers.isEmpty
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