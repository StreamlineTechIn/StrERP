import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:table_calendar/table_calendar.dart';

class LocationCalendar extends StatefulWidget {
  const LocationCalendar({Key? key}) : super(key: key);

  @override
  State<LocationCalendar> createState() => _LocationCalendarState();
}

class _LocationCalendarState extends State<LocationCalendar> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  String? _selectedEmployeeEmail;
  List<String> _employeeEmails = [];
  List<LatLng> _locationPath = [];
  LatLng? _mapCenter;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMemberEmails();
  }

  Future<void> _fetchMemberEmails() async {
    if (_auth.currentUser?.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to view members')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot memberLocations = await _firestore.collection('memberLocations').get();

      setState(() {
        _employeeEmails = memberLocations.docs
            .map((doc) => doc.id)
            .where((email) => email.isNotEmpty)
            .toList();
        // Sort emails alphabetically
        _employeeEmails.sort();
        // Initially select an email with data, if possible
        _selectFirstEmailWithData();
      });

      if (_employeeEmails.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No members found in the database')),
        );
      }
    } catch (e) {
      print("Error fetching member emails: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching members: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectFirstEmailWithData() async {
    for (String email in _employeeEmails) {
      String formattedDate = DateFormat('yyyy-M-dd').format(_selectedDate);
      QuerySnapshot dateDocs = await _firestore
          .collection('memberLocations')
          .doc(email)
          .collection('dates')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: formattedDate)
          .where(FieldPath.documentId, isLessThan: formattedDate + 'z')
          .get();

      if (dateDocs.docs.isNotEmpty) {
        setState(() {
          _selectedEmployeeEmail = email;
        });
        await _fetchLocationData();
        break;
      }
    }
    // If no email has data for the selected date, select the first email and fetch
    if (_selectedEmployeeEmail == null && _employeeEmails.isNotEmpty) {
      setState(() {
        _selectedEmployeeEmail = _employeeEmails.first;
      });
      await _fetchLocationData();
    }
  }

  Future<void> _fetchLocationData() async {
    if (_selectedDate == null || _selectedEmployeeEmail == null) {
      print("Cannot fetch location data: Date or employee email is null");
      return;
    }

    setState(() {
      _isLoading = true;
      _locationPath.clear();
    });

    try {
      String formattedDate = DateFormat('yyyy-M-dd').format(_selectedDate);
      print("Fetching location data for $_selectedEmployeeEmail on $formattedDate");

      QuerySnapshot dateDocs = await _firestore
          .collection('memberLocations')
          .doc(_selectedEmployeeEmail)
          .collection('dates')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: formattedDate)
          .where(FieldPath.documentId, isLessThan: formattedDate + 'z')
          .get();

      List<Map<String, dynamic>> allLocations = [];

      for (var doc in dateDocs.docs) {
        print("Found document: ${doc.id}");
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('locationStream')) {
          List<dynamic> locationStream = data['locationStream'];
          for (var loc in locationStream) {
            allLocations.add(loc as Map<String, dynamic>);
          }
        } else {
          print("No locationStream field in document ${doc.id}");
        }
      }

      if (allLocations.isEmpty) {
        print("No location data found for $_selectedEmployeeEmail on $formattedDate");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'No location data found for this employee on the selected date')),
        );
      }

      allLocations.sort((a, b) => (a['timestamp'] as Timestamp)
          .toDate()
          .compareTo((b['timestamp'] as Timestamp).toDate()));

      List<LatLng> smoothedPath = [];
      for (int i = 0; i < allLocations.length; i++) {
        double lat = allLocations[i]['latitude'];
        double lon = allLocations[i]['longitude'];
        LatLng point = LatLng(lat, lon);

        if (i > 0) {
          LatLng prevPoint = smoothedPath.last;
          double distance = _calculateDistance(prevPoint, point);
          if (distance > 50 && i < allLocations.length - 1) {
            LatLng nextPoint = LatLng(
                allLocations[i + 1]['latitude'], allLocations[i + 1]['longitude']);
            double avgLat = (prevPoint.latitude + point.latitude + nextPoint.latitude) / 3;
            double avgLon = (prevPoint.longitude + point.longitude + nextPoint.longitude) / 3;
            smoothedPath.add(LatLng(avgLat, avgLon));
          } else {
            smoothedPath.add(point);
          }
        } else {
          smoothedPath.add(point);
        }
      }

      setState(() {
        _locationPath = smoothedPath;
        if (_locationPath.isNotEmpty) {
          _mapCenter = _locationPath.first;
        }
      });

      print("Fetched ${allLocations.length} location points, smoothed to ${_locationPath.length} points");
    } catch (e) {
      print("Error fetching location data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching location data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000;
    double lat1 = point1.latitude * (pi / 180);
    double lat2 = point2.latitude * (pi / 180);
    double deltaLat = (point2.latitude - point1.latitude) * (pi / 180);
    double deltaLon = (point2.longitude - point1.longitude) * (pi / 180);

    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Employee Location History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Selected Employee Display
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _selectedEmployeeEmail != null
                    ? 'Selected Employee: $_selectedEmployeeEmail'
                    : 'Select an Employee',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // Section: List of Emails
            Container(
              height: 200,
              child: _isLoading && _employeeEmails.isEmpty
                  ? Center(child: CircularProgressIndicator())
                  : _employeeEmails.isEmpty
                  ? Center(child: Text('No employees found'))
                  : ListView.builder(
                itemCount: _employeeEmails.length,
                itemBuilder: (context, index) {
                  final email = _employeeEmails[index];
                  return ListTile(
                    title: Text(
                      email,
                      style: TextStyle(
                        color: _selectedEmployeeEmail == email
                            ? Colors.blue
                            : Colors.black,
                        fontWeight: _selectedEmployeeEmail == email
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () async {
                      setState(() {
                        _selectedEmployeeEmail = email;
                      });
                      await _fetchLocationData();
                    },
                  );
                },
              ),
            ),
            // Section: Calendar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select a Date',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime.now(),
              focusedDay: _focusedDate,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDate, day);
              },
              onDaySelected: (selectedDay, focusedDay) async {
                setState(() {
                  _selectedDate = selectedDay;
                  _focusedDate = focusedDay;
                });
                await _fetchLocationData();
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
            // Section: Map
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Location Path',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              height: 400,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _locationPath.isEmpty
                  ? Center(
                  child: Text(
                      _selectedEmployeeEmail == null
                          ? 'Please select an employee'
                          : 'No location data for this employee on the selected date',
                      textAlign: TextAlign.center))
                  : FlutterMap(
                options: MapOptions(
                  initialCenter: _mapCenter ?? LatLng(20.991388, 75.552986),
                  initialZoom: 15.0,
                  minZoom: 5.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _locationPath,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      if (_locationPath.isNotEmpty)
                        Marker(
                          point: _locationPath.first,
                          width: 40.0,
                          height: 40.0,
                          child: Icon(
                            Icons.start,
                            color: Colors.green,
                            size: 40.0,
                          ),
                        ),
                      if (_locationPath.length > 1)
                        Marker(
                          point: _locationPath.last,
                          width: 40.0,
                          height: 40.0,
                          child: Icon(
                            Icons.stop,
                            color: Colors.red,
                            size: 40.0,
                          ),
                        ),
                    ],
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