import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:str_erp/members/MemberAttendanceInfo.dart';
import 'package:table_calendar/table_calendar.dart';

class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({Key? key}) : super(key: key);

  @override
  State<AdminAttendancePage> createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Set<DateTime> _datesToHighlight = {};
  Map<DateTime, int> _events = {};
  Map<String, dynamic> attendanceDetails = {};
  bool showLatecomers = false;
  bool showEarlyLeavers = false;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<String, String> emailToNameCache = {};

  @override
  void initState() {
    super.initState();
    _fetchAttendanceDates();
  }

  Future<void> _fetchAttendanceDates() async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('memberAttendance').get();

      Map<DateTime, int> events = {};
      Set<DateTime> datesToHighlight = {};

      for (var doc in snapshot.docs) {
        String dateStr = doc.id;
        DateTime? date = _parseDateString(dateStr);

        if (date != null) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          int attendeeCount = 0;
          if (data['attendees'] is Map) {
            attendeeCount = (data['attendees'] as Map).length;
          }

          // Store dates in local time
          DateTime normalizedDate = DateTime(date.year, date.month, date.day);
          events[normalizedDate] = attendeeCount;
          datesToHighlight.add(normalizedDate);
        }
      }

      setState(() {
        _events = events;
        _datesToHighlight = datesToHighlight;
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

  Future<String?> fetchNameByEmail(String email) async {
    // Check if name is already cached
    if (emailToNameCache.containsKey(email)) {
      return emailToNameCache[email];
    }

    try {
      // Query the members collection
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: email)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Assume there's only one matching document
        var doc = snapshot.docs.first;
        String name = doc['Name']; // Field where the name is stored
        emailToNameCache[email] = name; // Cache the name
        return name;
      }
    } catch (e) {
      print('Error fetching name for email $email: $e');
    }
    return null; // Return null if name is not found
  }

  bool _hasAttendanceData(DateTime date) {
    // Convert the input date to start of day in local time
    DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    return _datesToHighlight.contains(normalizedDate);
  }

  DateTime? _parseDateString(String dateStr) {
    try {
      // First try parsing the standard ISO format
      return DateTime.parse(dateStr);
    } catch (e) {
      try {
        // If that fails, try parsing with DateFormat
        return DateFormat('yyyy-MM-dd').parse(dateStr);
      } catch (e) {
        print('Failed to parse date: $dateStr');
        return null;
      }
    }
  }

  Future<void> _fetchAttendanceDetails(DateTime date) async {
    try {
      // Format the date consistently using local time
      String dateStr = DateFormat('yyyy-MM-dd').format(date);
      print('Fetching attendance details for date: $dateStr'); // Debug log

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('memberAttendance')
          .doc(dateStr)
          .get();

      print('Document exists: ${doc.exists}'); // Debug log
      if (doc.exists) {
        print('Document data: ${doc.data()}'); // Debug log

        setState(() {
          attendanceDetails = doc.data() as Map<String, dynamic>;
        });
      } else {
        // Check if the date might be stored in a different format
        String alternativeDateStr = DateFormat('yyyy-M-d').format(date);
        print(
            'Trying alternative date format: $alternativeDateStr'); // Debug log

        doc = await FirebaseFirestore.instance
            .collection('memberAttendance')
            .doc(alternativeDateStr)
            .get();

        if (doc.exists) {
          setState(() {
            attendanceDetails = doc.data() as Map<String, dynamic>;
          });
        } else {
          setState(() {
            attendanceDetails = {};
          });
        }
      }
    } catch (e) {
      print('Error fetching attendance details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load attendance details: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  DateTime? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr == "N/A") {
      return null;
    }

    try {
      return DateFormat('hh:mm a').parse(timeStr);
    } catch (e) {
      try {
        return DateFormat('HH:mm').parse(timeStr);
      } catch (e) {
        print('Error parsing time: $timeStr');
        return null;
      }
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    // Convert to local time for comparison
    DateTime normalizedDate = DateTime(day.year, day.month, day.day);
    int count = _events[normalizedDate] ?? 0;
    return List.generate(count > 4 ? 4 : count, (index) => 'Attendance');
  }

  bool _isLate(String? checkIn, String? day) {
    if (checkIn == null) return false;

    try {
      // Parse the check-in time (assuming 24-hour format)
      List<String> timeParts = checkIn.split(':');
      int hours = int.parse(timeParts[0]);
      int minutes = int.parse(timeParts[1]);

      // Create a DateTime object for comparison
      DateTime checkInTime = DateTime(2024, 1, 1, hours, minutes);

      // Create cutoff time (10:15 AM)
      DateTime cutoffTime = DateTime(2024, 1, 1, 10, 15);

      return checkInTime.isAfter(cutoffTime);
    } catch (e) {
      print('Error parsing time: $e');
      return false;
    }
  }

  bool _isEarlyLeaver(String? checkOut, String? day) {
    if (checkOut == null || checkOut == "N/A") return false;

    try {
      // Parse the check-out time (assuming 24-hour format)
      List<String> timeParts = checkOut.split(':');
      int hours = int.parse(timeParts[0]);
      int minutes = int.parse(timeParts[1]);

      // Create a DateTime object for comparison
      DateTime checkOutTime = DateTime(2024, 1, 1, hours, minutes);

      // Create cutoff time (18:00)
      DateTime cutoffTime = DateTime(2024, 1, 1, 18, 0);

      return checkOutTime.isBefore(cutoffTime);
    } catch (e) {
      print('Error parsing time: $e');
      return false;
    }
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  Color _getCheckInColor(String? checkInTime) {
    if (checkInTime == null) {
      return Colors.orange; // Missing check-in
    }

    DateTime? checkIn = _parseTime(checkInTime);
    if (checkIn == null) {
      return Colors.orange; // Invalid time format
    }

    DateTime cutoffTime = DateFormat('HH:mm').parse("10:15");

    // Late if check-in time is later than 10:15 AM
    if (checkIn.isAfter(cutoffTime)) {
      return Colors.red; // Late
    }
    return Colors.green; // On time
  }

  Color _getCheckOutColor(String? checkOutTime) {
    if (checkOutTime == null || checkOutTime == "N/A") {
      return Colors.orange; // Missing check-out
    }

    DateTime? checkOut = _parseTime(checkOutTime);
    if (checkOut == null) {
      return Colors.orange; // Invalid time format
    }

    DateTime cutoffTime = DateFormat('HH:mm').parse("18:00");

    // Early if check-out time is earlier than 6:00 PM
    if (checkOut.isBefore(cutoffTime)) {
      return Colors.red; // Early
    }
    return Colors.green; // On time
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
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
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
                          _fetchAttendanceDetails(selectedDay);
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                        onFormatChanged: (format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        },
                        calendarStyle: CalendarStyle(
                          weekendTextStyle: TextStyle(color: Colors.red),

                          markerSize: 6.0,
                          markerDecoration: BoxDecoration(
                            color: Colors.teal,
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.teal,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          // Highlight dates with data
                          defaultDecoration: BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          weekendDecoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                          outsideDecoration: BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          // Custom day container decoration
                          cellMargin: EdgeInsets.all(4),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, date, _) {
                            bool hasData = _hasAttendanceData(date);
                            bool isWeekend = _isWeekend(date);
                            return Container(
                              margin: const EdgeInsets.all(4.0),
                              alignment: Alignment.center,
                              decoration: hasData
                                  ? BoxDecoration(
                                      color: Colors.teal.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.teal.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    )
                                  : null,
                              child: Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: isWeekend
                                      ? (hasData ? Colors.red : Colors.red[300])
                                      : (hasData
                                          ? Colors.teal
                                          : Colors.black87),
                                  fontWeight: hasData
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                          selectedBuilder: (context, date, _) {
                            bool isWeekend = _isWeekend(date);
                            return Container(
                              margin: const EdgeInsets.all(4.0),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isWeekend ? Colors.red : Colors.teal,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${date.day}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                          todayBuilder: (context, date, _) {
                            bool hasData = _hasAttendanceData(date);
                            return Container(
                              margin: const EdgeInsets.all(4.0),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: hasData
                                    ? Colors.teal.withOpacity(0.3)
                                    : Colors.teal.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.teal,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          formatButtonShowsNext: false,
                          titleTextStyle: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal,
                          ),
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.black),
                          weekendStyle: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      // Show Latecomers Checkbox
                      Expanded(
                        child: Card(
                          color: Colors.teal
                              .shade50, // Set background color for the card
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: CheckboxListTile(
                            value: showLatecomers,
                            onChanged: (bool? value) {
                              setState(() {
                                showLatecomers = value!;
                              });
                            },
                            title: Text(
                              "Late comers",
                              style: GoogleFonts.montserrat(
                                fontSize:
                                    12, // Adjust font size for better readability
                                color: Colors.teal[700],
                              ),
                              maxLines: 2, // Restrict to two lines
                              overflow: TextOverflow
                                  .ellipsis, // Handle overflow gracefully
                              textAlign:
                                  TextAlign.start, // Align text to the start
                            ),
                            activeColor:
                                Colors.teal, // Active color of the checkbox
                            controlAffinity: ListTileControlAffinity
                                .leading, // Checkbox position
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Show Early Leavers Checkbox
                      Expanded(
                        child: Card(
                          color: Colors.teal
                              .shade50, // Set background color for the card
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: CheckboxListTile(
                            value: showEarlyLeavers,
                            onChanged: (bool? value) {
                              setState(() {
                                showEarlyLeavers = value!;
                              });
                            },
                            title: Text(
                              "Early Leavers",
                              style: GoogleFonts.montserrat(
                                fontSize:
                                    12, // Adjust font size for better readability
                                color: Colors.teal[700],
                              ),
                              maxLines: 2, // Restrict to two lines
                              overflow: TextOverflow
                                  .clip, // Handle overflow gracefully
                              textAlign:
                                  TextAlign.start, // Align text to the start
                            ),
                            activeColor:
                                Colors.teal, // Active color of the checkbox
                            controlAffinity: ListTileControlAffinity
                                .leading, // Checkbox position
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: MediaQuery.of(context).size.height * 0.4,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _selectedDay == null
                      ? Center(
                          child: Text(
                            "Please select a date",
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              color: Colors.teal[700],
                            ),
                          ),
                        )
                      : attendanceDetails.isEmpty ||
                              !attendanceDetails.containsKey('attendees')
                          ? Center(
                              child: Text(
                                "No attendance records found for this date",
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  color: Colors.teal[700],
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount:
                                  attendanceDetails['attendees']?.length ?? 0,
                              itemBuilder: (context, index) {
                                try {
                                  // Safe access to attendance data with null checks
                                  if (attendanceDetails['attendees'] == null) {
                                    return Center(
                                      child: Text(
                                        "No attendance data available",
                                        style: GoogleFonts.montserrat(
                                          fontSize: 16,
                                          color: Colors.teal[700],
                                        ),
                                      ),
                                    );
                                  }

                                  String email = attendanceDetails['attendees']
                                      .keys
                                      .elementAt(index);
                                  Map<String, dynamic>? actions =
                                      attendanceDetails['attendees'][email];

                                  // Debug log
                                  print('Employee data for $email: $actions');

                                  if (actions == null) {
                                    // Handle case where employee has no action data
                                    return Card(
                                      color: Colors.teal.shade50,
                                      elevation: 2,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 8),
                                      child: ListTile(
                                        title: Text(
                                          email,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.teal[800],
                                          ),
                                        ),
                                        subtitle: Text(
                                          "No check-in/check-out data available",
                                          style: GoogleFonts.montserrat(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  // Safe access to check-in/check-out data with defaults
                                  String? checkIn = actions['checkIn'];
                                  String? checkOut =
                                      actions.containsKey('checkOut')
                                          ? actions['checkOut']
                                          : "N/A";
                                  String? day = actions['day'];

                                  bool isLate = _isLate(checkIn, day);
                                  bool isEarlyLeaver =
                                      _isEarlyLeaver(checkOut, day);

                                  // Apply color based on the conditions
                                  Color checkInColor =
                                      _getCheckInColor(checkIn);
                                  Color checkOutColor =
                                      _getCheckOutColor(checkOut);

                                  // Filtering based on conditions
                                  if (showLatecomers &&
                                      !showEarlyLeavers &&
                                      !isLate) {
                                    return Container();
                                  }

                                  if (showEarlyLeavers &&
                                      !showLatecomers &&
                                      !isEarlyLeaver) {
                                    return Container();
                                  }

                                  return FutureBuilder<String?>(
                                    future: fetchNameByEmail(email),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return ListTile(
                                          title: Text(
                                            'Loading...',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.teal[800],
                                            ),
                                          ),
                                        );
                                      }

                                      String displayName =
                                          snapshot.data ?? email;

                                      // Display attendance details with color-coded check-in and check-out
                                      return Card(
                                        color: Colors.teal.shade50,
                                        elevation: 2,
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 4, horizontal: 8),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                          title: Text(
                                            displayName,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.teal[800],
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceEvenly,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        "Check In: ",
                                                        style: GoogleFonts
                                                            .montserrat(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color:
                                                              Colors.grey[800],
                                                        ),
                                                      ),
                                                      Text(
                                                        checkIn ?? "Missing",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: checkInColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        "Check Out: ",
                                                        style: GoogleFonts
                                                            .montserrat(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color:
                                                              Colors.grey[800],
                                                        ),
                                                      ),
                                                      Text(
                                                        checkOut ?? "N/A",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: checkOutColor,
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                ],
                                              ),
                                            ],
                                          ),
                                          // Add this onTap handler to navigate to the EmployeeAttendancePage
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    EmployeeAttendancePage(
                                                  employeeEmail: email,
                                                  employeeName: displayName,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  );
                                } catch (e) {
                                  print('Error rendering attendance item: $e');
                                  return Card(
                                    color: Colors.red.shade50,
                                    elevation: 2,
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 4, horizontal: 8),
                                    child: ListTile(
                                      title: Text(
                                        "Error displaying attendance",
                                        style: GoogleFonts.montserrat(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.red[800],
                                        ),
                                      ),
                                      subtitle: Text(
                                        e.toString(),
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
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
