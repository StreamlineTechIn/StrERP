import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPathMap extends StatefulWidget {
  final String email;
  final String date;

  LocationPathMap({required this.email, required this.date});

  @override
  _LocationPathMapState createState() => _LocationPathMapState();
}

class _LocationPathMapState extends State<LocationPathMap> {
  GoogleMapController? _mapController;
  List<LatLng> _pathCoordinates = [];
  Set<Marker> _markers = {}; // Set for all markers
  Set<Polyline> _polylines = {}; // Set for polylines

  @override
  void initState() {
    super.initState();
    fetchLocations(widget.email, widget.date);
  }

  Future<void> fetchLocations(String email, String date) async {
    try {
      // Fetch the member document based on the email
      final querySnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: email)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Get the document ID for the matching member
        String docId = querySnapshot.docs.first.id;

        // Fetch the location data for the specific date
        final locationSnapshot = await FirebaseFirestore.instance
            .collection('members')
            .doc(docId)
            .collection('location')
            .doc(date)
            .get();

        if (locationSnapshot.exists) {
          // Retrieve the locationStream array from the document
          List<dynamic> locationStream = locationSnapshot.data()?['locationStream'] ?? [];

          setState(() {
            // Map the locationStream to a list of LatLng objects
            _pathCoordinates = locationStream.map((location) {
              double latitude = location['latitude'] ?? 0.0;
              double longitude = location['longitude'] ?? 0.0;
              return LatLng(latitude, longitude);
            }).toList();

            // Create the polyline with the fetched coordinates
            _polylines = {
              Polyline(
                polylineId: PolylineId('path'),
                points: _pathCoordinates,
                color: Colors.blue,
                width: 4,
              ),
            };

            // Add markers for the start and end points
            if (_pathCoordinates.isNotEmpty) {
              // Start Marker
              _markers.add(
                Marker(
                  markerId: MarkerId('start'),
                  position: _pathCoordinates.first,
                  infoWindow: InfoWindow(
                    title: 'Start',
                    snippet: 'Starting point',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), // Green for start
                ),
              );

              // End Marker
              _markers.add(
                Marker(
                  markerId: MarkerId('end'),
                  position: _pathCoordinates.last,
                  infoWindow: InfoWindow(
                    title: 'End',
                    snippet: 'Ending point',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Red for end
                ),
              );
            }
          });

          // Adjust the camera to show the last location on the map
          if (_pathCoordinates.isNotEmpty) {
            _mapController?.animateCamera(CameraUpdate.newLatLng(
              _pathCoordinates.last,
            ));
          }
        } else {
          print('No location data found for the specified date.');
        }
      } else {
        print('No member found with the provided email.');
      }
    } catch (e) {
      print('Error fetching locations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print("Path coordinates: $_pathCoordinates");
    return Scaffold(
      appBar: AppBar(title: Text('Google Map Example')),
      body: Container(
        height: MediaQuery.of(context).size.height, // Full-screen height
        width: MediaQuery.of(context).size.width,  // Full-screen width
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(20.9911605, 75.5515482), // Default location
            zoom: 14,
          ),
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          markers: _markers, // Set of markers
          polylines: _polylines, // Set of polylines
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
