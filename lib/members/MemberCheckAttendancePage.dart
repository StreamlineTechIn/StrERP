import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class MemberCheckAttendancePage extends StatefulWidget {
  const MemberCheckAttendancePage({super.key});

  @override
  State<MemberCheckAttendancePage> createState() =>
      _MemberCheckAttendancePage();
}

class _MemberCheckAttendancePage extends State<MemberCheckAttendancePage> {
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime? _selectedDay;
  Map<DateTime, int> _events = {};
  Map<DateTime, bool> _leaveDates = {};
  Map<DateTime, String> _leaveDescriptions = {};
  Map<String, dynamic> attendanceDetails = {};
  bool isLoading = false;
  final user = FirebaseAuth.instance.currentUser;

  Future<void> _getUserAttendanceForDate(DateTime date) async {
    if (user == null) {
      throw Exception('User not logged in');
    }

    setState(() {
      isLoading = true;
      attendanceDetails = {}; // Clear previous data
    });

    try {
      final userEmail = user?.email;
      final attendanceCollection =
          FirebaseFirestore.instance.collection('memberAttendance');

      String formattedDate =
          '${date.year}-${date.month.toString()}-${date.day.toString()}';

      final docSnapshot = await attendanceCollection.doc(formattedDate).get();

      Map<String, dynamic> newAttendanceDetails = {};

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final attendees = data?['attendees'] as Map<String, dynamic>?;

        if (attendees != null && attendees.containsKey(userEmail)) {
          final userRecord = attendees[userEmail] as Map<String, dynamic>;

          newAttendanceDetails[userEmail!] = {
            'date': docSnapshot.id,
            'checkIn': userRecord['checkIn'],
            'checkOut': userRecord['checkOut'],
            'day': userRecord['day'],
            'late': userRecord['late'] ?? false,
            'early': userRecord['early'] ?? false,
          };
        }
      }

      setState(() {
        attendanceDetails = newAttendanceDetails;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching attendance data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    DateTime normalizedDate = DateTime(day.year, day.month, day.day);
    int count = _events[normalizedDate] ?? 0;
    return List.generate(count > 4 ? 4 : count, (index) => 'Attendance');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Attendance data',
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.teal.shade700,
              Colors.teal.shade300,
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.4, 0.8],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
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
                                onDaySelected: (selectedDay, focusedDay) async {
                                  setState(() {
                                    _selectedDay = selectedDay;
                                    _focusedDay = focusedDay;
                                  });

                                  // Show leave description if it's a leave day
                                  DateTime normalizedDate = DateTime(
                                      selectedDay.year,
                                      selectedDay.month,
                                      selectedDay.day);
                                  if (_leaveDates[normalizedDate] == true) {
                                    String description =
                                        _leaveDescriptions[normalizedDate] ??
                                            'No description available';

                                    DateTime? fromDate =
                                        _leaveDescriptions.keys.firstWhere(
                                      (key) =>
                                          _leaveDescriptions[key] ==
                                          description,
                                      orElse: () =>
                                          normalizedDate, // Use the currently selected date as fallback
                                    );

                                    DateTime? toDate =
                                        _leaveDescriptions.keys.lastWhere(
                                      (key) =>
                                          _leaveDescriptions[key] ==
                                          description,
                                      orElse: () =>
                                          normalizedDate, // Use the currently selected date as fallback
                                    );

                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                        title: Row(
                                          children: [
                                            Icon(Icons.info,
                                                color: Colors.teal),
                                            SizedBox(width: 10),
                                            Text(
                                              'Leave Details',
                                              style: GoogleFonts.montserrat(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                                color: Colors.teal,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Description:',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              description,
                                              style: GoogleFonts.montserrat(
                                                  fontSize: 14,
                                                  color: Colors.black87),
                                            ),
                                            SizedBox(height: 10),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'From:',
                                                      style: GoogleFonts
                                                          .montserrat(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors
                                                                  .black87),
                                                    ),
                                                    Text(
                                                        DateFormat(
                                                                'dd MMM yyyy')
                                                            .format(fromDate!),
                                                        style: GoogleFonts
                                                            .montserrat(
                                                          fontSize: 14,
                                                          color: Colors.black87,
                                                        )),
                                                  ],
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'To:',
                                                      style: GoogleFonts
                                                          .montserrat(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors
                                                                  .black87),
                                                    ),
                                                    Text(
                                                        DateFormat(
                                                                'dd MMM yyyy')
                                                            .format(toDate!),
                                                        style: GoogleFonts
                                                            .montserrat(
                                                          fontSize: 14,
                                                          color: Colors.black87,
                                                        )),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: Text(
                                              'Close',
                                              style: GoogleFonts.montserrat(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  // Fetch attendance data when a day is selected
                                  await _getUserAttendanceForDate(selectedDay);
                                },
                                headerStyle: HeaderStyle(
                                  titleTextStyle: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors
                                        .teal, // Month and year text color
                                  ),
                                  leftChevronIcon: Icon(
                                    Icons.chevron_left,
                                    color: Colors.teal, // Left arrow color
                                  ),
                                  rightChevronIcon: Icon(
                                    Icons.chevron_right,
                                    color: Colors.teal, // Right arrow color
                                  ),
                                  formatButtonVisible:
                                      false, // Optionally hide the format button
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
                                  // Highlight leave dates in hot pink
                                  defaultTextStyle: TextStyle(
                                    color: Colors.black,
                                  ),
                                  outsideTextStyle: TextStyle(
                                    color: Colors.grey.shade300,
                                  ),
                                  holidayTextStyle: TextStyle(
                                    color: Colors.pink,
                                  ),
                                ),
                                calendarBuilders: CalendarBuilders(
                                  markerBuilder: (context, date, events) {
                                    DateTime normalizedDate = DateTime(
                                        date.year, date.month, date.day);
                                    List<Widget> markers = [];

                                    // Add leave date marker
                                    if (_leaveDates
                                        .containsKey(normalizedDate)) {
                                      markers.add(
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors
                                                .red, // Red for leave dates
                                            shape: BoxShape.circle,
                                          ),
                                          width: 6.0,
                                          height: 6.0,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 1.5),
                                        ),
                                      );
                                    }

                                    // Add attendance marker
                                    if (events.isNotEmpty) {
                                      markers.add(
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.teal,
                                            shape: BoxShape.circle,
                                          ),
                                          width: 6.0,
                                          height: 6.0,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 1.5),
                                        ),
                                      );
                                    }

                                    if (markers.isEmpty) {
                                      return null;
                                    }

                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: markers,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: MediaQuery.of(context).size.height * 0.4,
                      margin: EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 10.0),
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
                      child: isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : _selectedDay == null
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
                              : attendanceDetails.isEmpty
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
                                        itemCount: 1,
                                        itemBuilder: (context, index) {
                                          Map<String, dynamic> actions =
                                              attendanceDetails[user?.email];

                                          return Card(
                                            elevation: 5,
                                            color: Colors.white,
                                            margin: EdgeInsets.symmetric(
                                                vertical: 10.0),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    user?.email ?? '',
                                                    style:
                                                        GoogleFonts.montserrat(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  Divider(
                                                    color: Colors.teal.shade200,
                                                    thickness: 1,
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            "Check-in:",
                                                            style: GoogleFonts
                                                                .montserrat(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .black87,
                                                            ),
                                                          ),
                                                          SizedBox(height: 4),
                                                          Text(
                                                            actions['checkIn'] ??
                                                                'Not checked in',
                                                            style: GoogleFonts
                                                                .montserrat(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: actions[
                                                                          'late'] ==
                                                                      true
                                                                  ? Colors.red
                                                                  : Colors
                                                                      .green,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            "Check-out:",
                                                            style: GoogleFonts
                                                                .montserrat(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .black87,
                                                            ),
                                                          ),
                                                          SizedBox(height: 4),
                                                          Text(
                                                            actions['checkOut'] ??
                                                                'Not checked out',
                                                            style: GoogleFonts
                                                                .montserrat(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: actions[
                                                                          'early'] ==
                                                                      true
                                                                  ? Colors.red
                                                                  : Colors
                                                                      .green,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
