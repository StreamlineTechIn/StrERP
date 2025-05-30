  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:flutter/material.dart';
  import 'package:intl/intl.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:flutter_map/flutter_map.dart';
  import 'package:latlong2/latlong.dart';

  // Calendar Page: Select a date to view emails
  class CalendarPage extends StatefulWidget {
    const CalendarPage({Key? key}) : super(key: key);

    @override
    State<CalendarPage> createState() => _CalendarPageState();
  }

  class _CalendarPageState extends State<CalendarPage> {
    DateTime? _selectedDate;

    Future<List<String>> _fetchDates() async {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('memberLocations').get();
      return snapshot.docs.map((doc) => doc.id).toList();
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            "Select Date",
            style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          backgroundColor: Colors.teal,
        ),
        body: Column(
          children: [
            CalendarDatePicker(
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              onDateChanged: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },
            ),
            ElevatedButton(
              onPressed: _selectedDate == null
                  ? null
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MemberEmailsPage(date: DateFormat('yyyy-M-dd').format(_selectedDate!)),
                  ),
                );
              },
              child: Text("Show Members"),
            ),
          ],
        ),
      );
    }
  }

  // Emails Page: Show emails for the selected date
  class MemberEmailsPage extends StatefulWidget {
    final String date;
    const MemberEmailsPage({Key? key, required this.date}) : super(key: key);

    @override
    State<MemberEmailsPage> createState() => _MemberEmailsPageState();
  }

  class _MemberEmailsPageState extends State<MemberEmailsPage> {
    List<String> _emails = [];
    bool _isLoading = true;

    @override
    void initState() {
      super.initState();
      _fetchEmails();
    }

    Future<void> _fetchEmails() async {
      try {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('memberLocations')
            .doc(widget.date)
            .collection('users')
            .get();

        List<String> emails = snapshot.docs.map((doc) => doc.id).toSet().toList();

        setState(() {
          _emails = emails..sort();
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load emails: $e'), backgroundColor: Colors.red),
        );
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            "/memberLocations/${widget.date}",
            style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          backgroundColor: Colors.teal,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _emails.isEmpty
            ? Center(
          child: Text(
            "No members found for this date",
            style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
          ),
        )
            : ListView.builder(
          padding: EdgeInsets.all(16.0),
          itemCount: _emails.length,
          itemBuilder: (context, index) {
            String email = _emails[index];
            return Card(
              elevation: 5,
              color: Colors.white,
              margin: EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(
                  email,
                  style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                trailing: Icon(Icons.arrow_forward, color: Colors.teal),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MemberLocationMapPage(
                        email: email,
                        date: widget.date,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
    }
  }

  // Map Page: Show trips on a map for the selected email and date
  class MemberLocationMapPage extends StatefulWidget {
    final String email;
    final String date;
    const MemberLocationMapPage({Key? key, required this.email, required this.date}) : super(key: key);

    @override
    State<MemberLocationMapPage> createState() => _MemberLocationMapPageState();
  }

  class _MemberLocationMapPageState extends State<MemberLocationMapPage> {
    Map<String, List<LatLng>> _trips = {};
    LatLng? _mapCenter;
    bool _isLoading = true;

    @override
    void initState() {
      super.initState();
      _fetchLocationData();
    }

    Future<void> _fetchLocationData() async {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('memberLocations')
            .doc(widget.date)
            .collection('users')
            .doc(widget.email)
            .get();

        Map<String, List<LatLng>> trips = {};
        LatLng? firstPoint;

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data.forEach((tripId, tripData) {
            if (tripData['locationStream'] is List) {
              List<LatLng> tripPoints = [];
              for (var loc in tripData['locationStream']) {
                double lat = loc['latitude']?.toDouble() ?? 0.0;
                double lon = loc['longitude']?.toDouble() ?? 0.0;
                if (lat != 0.0 && lon != 0.0) {
                  tripPoints.add(LatLng(lat, lon));
                  if (firstPoint == null) firstPoint = LatLng(lat, lon);
                }
              }
              if (tripPoints.isNotEmpty) trips[tripId] = tripPoints;
            }
          });
        }

        setState(() {
          _trips = trips;
          _mapCenter = firstPoint ?? LatLng(20.991388, 75.552986);
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load location data: $e'), backgroundColor: Colors.red),
        );
      }
    }

    List<Color> _tripColors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.cyan,
      Colors.pink,
    ];

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            "/memberLocations/${widget.date}/${widget.email}",
            style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          backgroundColor: Colors.teal,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _trips.isEmpty
            ? Center(
          child: Text(
            "No location data found for this date",
            style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
          ),
        )
            : Column(
          children: [
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _mapCenter!,
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
                  ..._trips.entries.map((entry) {
                    String tripId = entry.key;
                    List<LatLng> points = entry.value;
                    int colorIndex = int.parse(tripId.replaceFirst('trip', '')) - 1;
                    Color tripColor = _tripColors[colorIndex % _tripColors.length];

                    return PolylineLayer(
                      polylines: [
                        Polyline(points: points, strokeWidth: 4.0, color: tripColor),
                      ],
                    );
                  }).toList(),
                  MarkerLayer(
                    markers: _trips.entries
                        .map((entry) {
                      List<LatLng> points = entry.value;
                      if (points.isNotEmpty) {
                        int colorIndex = int.parse(entry.key.replaceFirst('trip', '')) - 1;
                        Color markerColor = _tripColors[colorIndex % _tripColors.length];
                        return [
                          Marker(
                            point: points.first,
                            width: 40.0,
                            height: 40.0,
                            child: Icon(Icons.start, color: markerColor, size: 40.0),
                          ),
                          Marker(
                            point: points.last,
                            width: 40.0,
                            height: 40.0,
                            child: Icon(Icons.stop, color: markerColor, size: 40.0),
                          ),
                        ];
                      }
                      return <Marker>[];
                    })
                        .expand((i) => i)
                        .toList()
                        .cast<Marker>(),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Trips Legend",
                    style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  ..._trips.keys.map((tripId) {
                    int colorIndex = int.parse(tripId.replaceFirst('trip', '')) - 1;
                    Color tripColor = _tripColors[colorIndex % _tripColors.length];
                    return Row(
                      children: [
                        Container(width: 16, height: 16, color: tripColor),
                        SizedBox(width: 8),
                        Text(
                          tripId,
                          style: GoogleFonts.montserrat(fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
