
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

// For simplicity, the User model is here. It's best to keep it in a separate file.
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

  bool _isSharingLocation = true;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  List<AppUser> _nearbyUsers = [];
  bool _isLoading = true;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    // When the widget is first created, start the process of getting the location.
    _determinePosition();
  }

  // --- State Management and Logic ---

  // Toggles location sharing and updates the UI
  void _toggleLocationSharing(bool value) {
    // setState() tells Flutter that the state has changed and the UI needs to be rebuilt.
    setState(() {
      _isSharingLocation = value;
    });

    if (!value) {
      // In a real app, update user status in Firestore.
      setState(() {
        _nearbyUsers.clear(); // Clear the list to reflect the change
      });
      print("Location sharing disabled.");
    } else {
      // Re-fetch users if sharing is turned back on.
      _fetchNearbyUsers();
      print("Location sharing enabled.");
    }
  }

  // Fetches the user's current GPS location
  Future<void> _determinePosition() async {
    // Check for permissions and services
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Handle service not enabled
      setState(() => _isLoading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      return;
    }

    // Get position and update the state
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
      _markers.add(
        Marker(
          markerId: const MarkerId('currentUser'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      _isLoading = false;
    });

    _animateCameraToPosition();
    _fetchNearbyUsers(); // Fetch users after getting location
  }

  // DUMMY DATA: Replace this with your actual Firestore call
  Future<void> _fetchNearbyUsers() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network
    // This is where you will fetch users from Firestore and filter them.
    // For now, we use dummy data to build the UI.
    final dummyUsers = [
      AppUser(id: '1', name: 'Alex', interests: ['Coffee', 'AI']),
      AppUser(id: '2', name: 'Maria', interests: ['Music', 'Basketball']),
      AppUser(id: '3', name: 'Sam', interests: ['AI', 'Music']),
      AppUser(id: '4', name: 'Chloe', interests: ['Coffee']),
      AppUser(id: '5', name: 'David', interests: ['Basketball']),
    ];

    // Update the user list and rebuild the UI
    setState(() {
      _nearbyUsers = dummyUsers;
    });
  }

  // Animates the map camera to the user's current position
  void _animateCameraToPosition() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 15.5,
          ),
        ),
      );
    }
  }

  // --- Build Method ---
  // This method builds the UI based on the current state variables.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
            onChanged: _toggleLocationSharing, // Call our method
            activeColor: Colors.deepPurple,
          ),
        ],
      ),
      body: Stack(
        children: [
          // --- Google Map Background ---
          if (_currentPosition != null)
            GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: CameraPosition(
                target:
                    LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                zoom: 15.5,
              ),
              markers: _markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            )
          else if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            const Center(child: Text('Enable location to find matches!')),

          // --- Draggable Bottom Sheet ---
          DraggableScrollableSheet(
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
                      child: _nearbyUsers.isEmpty
                          ? const Center(
                              child: Text('No one nearby yet...',
                                  style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _nearbyUsers.length,
                              itemBuilder: (context, index) {
                                final user = _nearbyUsers[index];
                                return _buildUserCard(user);
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
    );
  }

  // --- A beautiful card for each user ---
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