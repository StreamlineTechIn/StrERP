import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeamLeadApprovalPage extends StatefulWidget {
  const TeamLeadApprovalPage({Key? key}) : super(key: key);

  @override
  State<TeamLeadApprovalPage> createState() => _TeamLeadApprovalPageState();
}

class _TeamLeadApprovalPageState extends State<TeamLeadApprovalPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? userName;
  bool _showCheckIns = true; // Toggle state

  Future<void> _updateRequestStatus(String requestId, String status) async {
    try {
      DocumentSnapshot requestDoc = await _firestore
          .collection('remoteCheckInRequests')
          .doc(requestId)
          .get();

      await _firestore
          .collection('remoteCheckInRequests')
          .doc(requestId)
          .update({'status': status});

      if (status == 'approved') {
        await _updateUserAttendance(
            userEmail: requestDoc['userEmail'],
            date: requestDoc['date'],
            time: requestDoc['time']);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request $status successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request: $e')),
      );
    }
  }

  Future<void> _updateUserAttendance({
    required String userEmail,
    required String date,
    required String time,
  }) async {
    try {
      DateTime parsedDate = DateTime.parse(date);
      String formattedDate = DateFormat('yyyy-M-d').format(parsedDate);

      DocumentReference docRef = _firestore
          .collection('memberAttendance')
          .doc(formattedDate);

      await docRef.set({
        'attendees': {
          userEmail: {
            'checkIn': time,
            'day': DateFormat('EEEE').format(parsedDate),
          }
        }
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update attendance: $e')),
      );
    }
  }

  String _formatRequestDate(String date, String time) {
    return '$date at $time';
  }

  void _openMap(double latitude, double longitude) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          latitude: latitude,
          longitude: longitude,
          userName: userName ?? 'User',
        ),
      ),
    );
  }

  Future<void> _fetchMemberDocIdAndName() async {
    final userEmail = _auth.currentUser?.email;
    if (userEmail != null) {
      try {
        final query = await _firestore
            .collection('members')
            .where('email', isEqualTo: userEmail)
            .get();

        if (query.docs.isNotEmpty) {
          final userDoc = query.docs.first;
          setState(() {
            userName = userDoc['Name'] ?? 'User';
          });
        }
      } catch (e) {
        print('Error fetching member document: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchMemberDocIdAndName();
  }

  Widget _buildToggleButtons() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildToggleButton(
            text: 'Check-Ins',
            isSelected: _showCheckIns,
            onPressed: () => setState(() => _showCheckIns = true),
          ),
          const SizedBox(width: 10),
          _buildToggleButton(
            text: 'Check-Outs',
            isSelected: !_showCheckIns,
            onPressed: () => setState(() => _showCheckIns = false),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String text,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.teal : Colors.grey,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildCheckInsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('remoteCheckInRequests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "No pending check-in requests",
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final request = snapshot.data!.docs[index];
            return _buildCheckInCard(request);
          },
        );
      },
    );
  }

  Widget _buildCheckOutsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('remoteCheckOuts')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "No check-out records",
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final checkOut = snapshot.data!.docs[index];
            return _buildCheckOutCard(checkOut);
          },
        );
      },
    );
  }

  Widget _buildCheckInCard(DocumentSnapshot request) {
    final requestId = request.id;
    final userEmail = request['userEmail'];
    final latitude = request['latitude'];
    final longitude = request['longitude'];
    final date = request['date'];
    final time = request['time'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      elevation: 4,
      child: ListTile(
        title: Text("User: $userEmail"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Requested at: ${_formatRequestDate(date, time)}"),
            Text("Location: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}"),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () {
                _updateUserAttendance(
                    userEmail: userEmail, date: date, time: time);
                _updateRequestStatus(requestId, 'approved');
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _updateRequestStatus(requestId, 'rejected'),
            ),
            IconButton(
              icon: const Icon(Icons.map, color: Colors.blue),
              onPressed: () => _openMap(latitude, longitude),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckOutCard(DocumentSnapshot checkOut) {
    final userEmail = checkOut['userEmail'];
    final latitude = checkOut['latitude'];
    final longitude = checkOut['longitude'];
    final date = checkOut['date'];
    final time = checkOut['time'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      elevation: 4,
      child: ListTile(
        title: Text("User: $userEmail"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Checked out at: ${_formatRequestDate(date, time)}"),
            Text("Location: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}"),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.map, color: Colors.blue),
          onPressed: () => _openMap(latitude, longitude),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showCheckIns ? "Remote Check-In Requests" : "Remote Check-Outs"),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          _buildToggleButtons(),
          Expanded(
            child: _showCheckIns ? _buildCheckInsList() : _buildCheckOutsList(),
          ),
        ],
      ),
    );
  }
}

class MapScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String userName;

  const MapScreen({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.userName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Location'),
        backgroundColor: Colors.teal,
      ),
      body: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          print('Map created successfully');
        },
        initialCameraPosition: CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: MarkerId('userLocation'),
            position: LatLng(latitude, longitude),
            infoWindow: InfoWindow(title: ' $userName'), // Show the userName
          ),
        },
        zoomControlsEnabled: true,
        mapType: MapType.normal,
        compassEnabled: true,
        myLocationEnabled: true,
      ),
    );
  }
}
