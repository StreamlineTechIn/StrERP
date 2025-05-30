import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'MemberLocationMapPage.dart';

class AttendanceForEmailPage extends StatefulWidget {
  const AttendanceForEmailPage({Key? key}) : super(key: key);

  @override
  State<AttendanceForEmailPage> createState() => _AttendanceForEmailPageState();
}

class _AttendanceForEmailPageState extends State<AttendanceForEmailPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Set<DateTime> _datesToHighlight = {};
  Map<DateTime, List<String>> _events = {}; // Map of dates to list of emails
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceDates();
    // For testing: If you know a date with data, set it here
    // _focusedDay = DateTime(2025, 5, 22);
    // _selectedDay = _focusedDay;
  }

  Future<void> _fetchAttendanceDates() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('memberAttendance')
          .get();

      print('Fetched ${snapshot.docs.length} documents from memberAttendance');

      Map<DateTime, List<String>> events = {};
      Set<DateTime> datesToHighlight = {};

      for (var doc in snapshot.docs) {
        String dateStr = doc.id;
        DateTime? date = _parseDateString(dateStr);

        if (date != null) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          print('Document ID: $dateStr, Attendees: ${data['attendees']}');

          if (data['attendees'] is Map) {
            DateTime normalizedDate = DateTime(date.year, date.month, date.day);
            List<String> emails = [];
            (data['attendees'] as Map).forEach((email, _) {
              emails.add(email);
            });

            if (emails.isNotEmpty) {
              events[normalizedDate] = emails;
              datesToHighlight.add(normalizedDate);
              print('Highlighted date: $normalizedDate with emails: $emails');
            }
          }
        }
      }

      setState(() {
        _events = events;
        _datesToHighlight = datesToHighlight;
        print('Updated events: $_events');
      });
    } catch (e) {
      print('Error fetching attendance dates: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load attendance data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  DateTime? _parseDateString(String dateStr) {
    try {
      return DateTime.parse(dateStr); // Handles yyyy-MM-dd (e.g., 2025-05-23)
    } catch (e) {
      try {
        return DateFormat('yyyy-M-d').parse(dateStr); // Handles yyyy-M-d (e.g., 2025-5-23)
      } catch (e) {
        print('Failed to parse date: $dateStr, Error: $e');
        return null;
      }
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    DateTime normalizedDate = DateTime(day.year, day.month, day.day);
    return _events[normalizedDate] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Admin Attendance",
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal,
      ),
      body: Container(
        color: Colors.grey[50],
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: Colors.white,
                    child: TableCalendar(
                      firstDay: DateTime.utc(2023, 1, 1),
                      lastDay: DateTime.utc(2025, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) {
                        return isSameDay(_selectedDay, day);
                      },
                      eventLoader: _getEventsForDay,
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      headerStyle: HeaderStyle(
                        titleTextStyle: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: Colors.teal,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: Colors.teal,
                        ),
                        formatButtonVisible: false,
                      ),
                      calendarStyle: CalendarStyle(
                        markerDecoration: BoxDecoration(
                          color: Colors.teal,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Colors.tealAccent,
                          shape: BoxShape.circle,
                        ),
                        defaultTextStyle: TextStyle(color: Colors.black),
                        outsideTextStyle: TextStyle(color: Colors.grey.shade300),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          if (events.isNotEmpty) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                events.length > 4 ? 4 : events.length,
                                    (index) => Container(
                                  decoration: BoxDecoration(
                                    color: Colors.teal,
                                    shape: BoxShape.circle,
                                  ),
                                  width: 6.0,
                                  height: 6.0,
                                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ),
                Container(
                  height: MediaQuery.of(context).size.height * 0.4,
                  margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade100, Colors.teal.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _selectedDay == null
                      ? Center(
                    child: Text(
                      "Please select a date",
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  )
                      : _getEventsForDay(_selectedDay!).isEmpty
                      ? Center(
                    child: Text(
                      "No attendance records found",
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  )
                      : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ListView.builder(
                      itemCount: _getEventsForDay(_selectedDay!).length,
                      itemBuilder: (context, index) {
                        String email = _getEventsForDay(_selectedDay!)[index];
                        return Card(
                          elevation: 5,
                          color: Colors.white,
                          margin: EdgeInsets.symmetric(vertical: 10.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(
                              email,
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward,
                              color: Colors.teal,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CalendarPage(

                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

