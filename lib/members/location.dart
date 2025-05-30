import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:async'; // To use Timer

class LocationPage extends StatefulWidget {
  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  bool isLoading = false;
  String? _errorMessage;
  late Timer _timer;
  bool isTracking = false; // Track whether the location is being stored or not

  // Fixed reference point (latitude and longitude) to compare user's location with
  double referenceLatitude = 20.9911605; // Example latitude
  double referenceLongitude = 75.5515482; // Example longitude

  // Function to check and request location permission using Geolocator
  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    // If permission is denied or denied forever, request permission
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    // Return whether the permission is granted
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  // Function to store location data
  Future<void> _storeLocationData() async {
    try {
      setState(() {
        isLoading = true; // Show loading indicator
      });

      // Get the current user from Firebase Authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not logged in.';
          isLoading = false;
        });
        return;
      }

      String userEmail = user.email ?? '';

      // Check if location permission is granted
      bool permissionGranted = await _checkLocationPermission();
      if (!permissionGranted) {
        setState(() {
          isLoading = false; // Hide loading indicator if permission is denied
        });
        return;
      }

      // Get current location
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Calculate the distance between the user's current position and the reference point
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        referenceLatitude,
        referenceLongitude,
      );

      // If the user is within 100 meters of the reference point, do not store the location
      if (distance <= 100) {
        setState(() {
          isLoading = false;
        });
        print("User is within 100 meters of the reference point. Not storing location.");
        return;
      }

      // Prepare location data with manual timestamp using DateTime.now()
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': Timestamp.now(), // Use Firestore's Timestamp method
      };

      // Format the current date to store as the document ID
      String formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

      // Find the user document by email
      final QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: userEmail) // Using user's email as ID
          .get();

      if (userSnapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No user found with the provided email.';
          isLoading = false;
        });
        return;
      }

      final DocumentSnapshot userDoc = userSnapshot.docs.first;

      // Update the user's location in the 'locationStream' array in the document
      await userDoc.reference.collection('location').doc(formattedDate).update({
        'locationStream': FieldValue.arrayUnion([locationData]), // Add new location data to the array
      });

      setState(() {
        isLoading = false; // Hide loading indicator
      });

      print("Location data stored successfully for user: $userEmail");
    } catch (e) {
      setState(() {
        _errorMessage = 'Error storing location data: $e';
        isLoading = false; // Hide loading indicator in case of error
      });
      print("Error storing location data: $e");
    }
  }

  // Start tracking location data
  void _startTracking() {
    if (!isTracking) {
      setState(() {
        isTracking = true;
      });
      _timer = Timer.periodic(Duration(seconds: 10), (timer) {
        _storeLocationData();
      });
    }
  }

  // Stop tracking location data
  void _stopTracking() {
    if (isTracking) {
      setState(() {
        isTracking = false;
      });
      _timer.cancel(); // Stop the timer
    }
  }

  @override
  void dispose() {
    if (isTracking) {
      _timer.cancel(); // Cancel the timer when the page is disposed
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Store Location Data'),
      ),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator() // Show loading spinner while storing data
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _startTracking, // Start tracking when pressed
              child: Text('Start Tracking'),
            ),
            ElevatedButton(
              onPressed: _stopTracking, // Stop tracking when pressed
              child: Text('Stop Tracking'),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
