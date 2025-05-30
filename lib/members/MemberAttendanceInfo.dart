import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

class EmployeeAttendancePage extends StatefulWidget {
  final String employeeEmail;
  final String employeeName;

  const EmployeeAttendancePage({
    Key? key,
    required this.employeeEmail,
    required this.employeeName,
  }) : super(key: key);

  @override
  State<EmployeeAttendancePage> createState() => _EmployeeAttendancePageState();
}

class _EmployeeAttendancePageState extends State<EmployeeAttendancePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Set<DateTime> _attendanceDates = {};
  Map<DateTime, Map<String, dynamic>> _attendanceDetails = {};
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isLoading = true;

  // Statistics
  int _totalWorkdays = 0;
  int _totalPresent = 0;
  int _totalLate = 0;
  int _totalEarlyLeave = 0;

  @override
  void initState() {
    super.initState();
    _fetchEmployeeAttendanceData();
  }

  Future<void> _fetchEmployeeAttendanceData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('memberAttendance').get();

      Set<DateTime> attendanceDates = {};
      Map<DateTime, Map<String, dynamic>> attendanceDetails = {};
      int presentCount = 0;
      int lateCount = 0;
      int earlyLeaveCount = 0;

      for (var doc in snapshot.docs) {
        String dateStr = doc.id;
        DateTime? date = _parseDateString(dateStr);

        if (date != null) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          if (data['attendees'] is Map &&
              (data['attendees'] as Map).containsKey(widget.employeeEmail)) {
            Map<String, dynamic> employeeData =
                data['attendees'][widget.employeeEmail] as Map<String, dynamic>;

            // Normalize date to start of day in local time
            DateTime normalizedDate = DateTime(date.year, date.month, date.day);

            // Store attendance details
            attendanceDates.add(normalizedDate);
            attendanceDetails[normalizedDate] = employeeData;

            // Update statistics
            presentCount++;

            // Check if late
            if (_isLate(employeeData['checkIn'])) {
              lateCount++;
            }

            // Check if early leave
            if (_isEarlyLeaver(employeeData['checkOut'])) {
              earlyLeaveCount++;
            }
          }
        }
      }

      // Calculate total workdays (excluding weekends)
      DateTime startDate = DateTime(DateTime.now().year, 1, 1);
      DateTime endDate = DateTime.now();
      int totalWorkdays = 0;

      for (DateTime date = startDate;
          date.isBefore(endDate);
          date = date.add(Duration(days: 1))) {
        // Skip weekends
        if (date.weekday != DateTime.saturday &&
            date.weekday != DateTime.sunday) {
          totalWorkdays++;
        }
      }

      setState(() {
        _attendanceDates = attendanceDates;
        _attendanceDetails = attendanceDetails;
        _totalWorkdays = totalWorkdays;
        _totalPresent = presentCount;
        _totalLate = lateCount;
        _totalEarlyLeave = earlyLeaveCount;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching employee attendance data: $e');
      setState(() {
        _isLoading = false;
      });

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
      // First try parsing the standard ISO format
      return DateTime.parse(dateStr);
    } catch (e) {
      try {
        // If that fails, try parsing with DateFormat
        return DateFormat('yyyy-M-d').parse(dateStr);
      } catch (e) {
        print('Failed to parse date: $dateStr');
        return null;
      }
    }
  }

  bool _hasAttendance(DateTime day) {
    // Convert to start of day in local time for comparison
    DateTime normalizedDate = DateTime(day.year, day.month, day.day);
    return _attendanceDates.contains(normalizedDate);
  }

  bool _isLate(String? checkInTime) {
    if (checkInTime == null) return false;

    try {
      // Parse the check-in time (assuming 24-hour format)
      List<String> timeParts = checkInTime.split(':');
      int hours = int.parse(timeParts[0]);
      int minutes = int.parse(timeParts[1]);

      // Create a DateTime object for comparison
      DateTime checkInDateTime = DateTime(2024, 1, 1, hours, minutes);

      // Create cutoff time (10:15 AM)
      DateTime cutoffTime = DateTime(2024, 1, 1, 10, 15);

      return checkInDateTime.isAfter(cutoffTime);
    } catch (e) {
      print('Error parsing time: $e');
      return false;
    }
  }

  bool _isEarlyLeaver(String? checkOutTime) {
    if (checkOutTime == null || checkOutTime == "N/A") return false;

    try {
      // Parse the check-out time (assuming 24-hour format)
      List<String> timeParts = checkOutTime.split(':');
      int hours = int.parse(timeParts[0]);
      int minutes = int.parse(timeParts[1]);

      // Create a DateTime object for comparison
      DateTime checkOutDateTime = DateTime(2024, 1, 1, hours, minutes);

      // Create cutoff time (18:00)
      DateTime cutoffTime = DateTime(2024, 1, 1, 18, 0);

      return checkOutDateTime.isBefore(cutoffTime);
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

    try {
      List<String> timeParts = checkInTime.split(':');
      int hours = int.parse(timeParts[0]);
      int minutes = int.parse(timeParts[1]);

      DateTime checkIn = DateTime(2024, 1, 1, hours, minutes);
      DateTime cutoffTime = DateTime(2024, 1, 1, 10, 15);

      // Late if check-in time is later than 10:15 AM
      if (checkIn.isAfter(cutoffTime)) {
        return Colors.red; // Late
      }
      return Colors.green; // On time
    } catch (e) {
      return Colors.orange; // Invalid time format
    }
  }

  Color _getCheckOutColor(String? checkOutTime) {
    if (checkOutTime == null || checkOutTime == "N/A") {
      return Colors.orange; // Missing check-out
    }

    try {
      List<String> timeParts = checkOutTime.split(':');
      int hours = int.parse(timeParts[0]);
      int minutes = int.parse(timeParts[1]);

      DateTime checkOut = DateTime(2024, 1, 1, hours, minutes);
      DateTime cutoffTime = DateTime(2024, 1, 1, 18, 0);

      // Early if check-out time is earlier than 6:00 PM
      if (checkOut.isBefore(cutoffTime)) {
        return Colors.red; // Early
      }
      return Colors.green; // On time
    } catch (e) {
      return Colors.orange; // Invalid time format
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.employeeName}'s Attendance",
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.teal))
          : Container(
              color: Colors.grey[50],
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Statistics Cards
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            _buildStatCard(
                              "Present",
                              "$_totalPresent",
                              Colors.teal,
                              Icons.check_circle_outline,
                            ),
                            _buildStatCard(
                              "Late",
                              "$_totalLate",
                              Colors.amber,
                              Icons.watch_later_outlined,
                            ),
                            _buildStatCard(
                              "Early Leave",
                              "$_totalEarlyLeave",
                              Colors.red,
                              Icons.exit_to_app,
                            ),
                          ],
                        ),
                      ),

                      // Attendance Rate
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text(
                                  "Attendance Rate",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: _totalWorkdays > 0
                                      ? _totalPresent / _totalWorkdays
                                      : 0,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.teal,
                                  ),
                                  minHeight: 10,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "${(_totalWorkdays > 0 ? (_totalPresent / _totalWorkdays * 100).toStringAsFixed(1) : '0')}%",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Calendar
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
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
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
                                defaultDecoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                weekendDecoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                outsideDecoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                cellMargin: EdgeInsets.all(4),
                              ),
                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, date, _) {
                                  bool hasAttendance = _hasAttendance(date);
                                  bool isWeekend = _isWeekend(date);
                                  return Container(
                                    margin: const EdgeInsets.all(4.0),
                                    alignment: Alignment.center,
                                    decoration: hasAttendance
                                        ? BoxDecoration(
                                            color: Colors.teal.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color:
                                                  Colors.teal.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          )
                                        : null,
                                    child: Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        color: isWeekend
                                            ? (hasAttendance
                                                ? Colors.red
                                                : Colors.red[300])
                                            : (hasAttendance
                                                ? Colors.teal
                                                : Colors.black87),
                                        fontWeight: hasAttendance
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
                                      color:
                                          isWeekend ? Colors.red : Colors.teal,
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
                                  bool hasAttendance = _hasAttendance(date);
                                  return Container(
                                    margin: const EdgeInsets.all(4.0),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: hasAttendance
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
                                formatButtonVisible: true,
                                titleCentered: true,
                                titleTextStyle: GoogleFonts.montserrat(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal,
                                ),
                              ),
                              daysOfWeekStyle: DaysOfWeekStyle(
                                weekdayStyle: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                                weekendStyle: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Attendance Details
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _selectedDay == null
                            ? Center(
                                child: Text(
                                  "Please select a date to view details",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    color: Colors.teal[700],
                                  ),
                                ),
                              )
                            : _buildAttendanceDetails(_selectedDay!),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceDetails(DateTime date) {
    // Normalize date for comparison
    DateTime normalizedDate = DateTime(date.year, date.month, date.day);

    // Check if there's attendance data for this date
    if (!_attendanceDates.contains(normalizedDate)) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              "No attendance record for this date",
              style: GoogleFonts.montserrat(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
      );
    }

    // Get attendance details
    Map<String, dynamic> details = _attendanceDetails[normalizedDate]!;
    String? checkIn = details['checkIn'];
    String? checkOut =
        details.containsKey('checkOut') ? details['checkOut'] : "N/A";

    // Determine status
    bool isLate = _isLate(checkIn);
    bool isEarlyLeave = _isEarlyLeaver(checkOut);

    // Get status colors
    Color checkInColor = _getCheckInColor(checkIn);
    Color checkOutColor = _getCheckOutColor(checkOut);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Attendance Details",
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal[700],
              ),
            ),
            Divider(color: Colors.teal[200]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDetailItem(
                    "Date",
                    DateFormat('dd MMM yyyy').format(normalizedDate),
                    Colors.black87),
                _buildDetailItem("Day",
                    DateFormat('EEEE').format(normalizedDate), Colors.black87),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDetailItem(
                  "Check In",
                  checkIn ?? "Missing",
                  checkInColor,
                  suffix: isLate ? " (Late)" : "",
                ),
                _buildDetailItem(
                  "Check Out",
                  checkOut!,
                  checkOutColor,
                  suffix: isEarlyLeave ? " (Early)" : "",
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusCard(isLate, isEarlyLeave),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, Color valueColor,
      {String suffix = ""}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "$value$suffix",
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isLate, bool isEarlyLeave) {
    String status;
    Color statusColor;
    IconData statusIcon;

    if (isLate && isEarlyLeave) {
      status = "Late Arrival & Early Departure";
      statusColor = Colors.red;
      statusIcon = Icons.warning_rounded;
    } else if (isLate) {
      status = "Late Arrival";
      statusColor = Colors.amber;
      statusIcon = Icons.watch_later_outlined;
    } else if (isEarlyLeave) {
      status = "Early Departure";
      statusColor = Colors.orange;
      statusIcon = Icons.exit_to_app;
    } else {
      status = "On Time";
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor),
          SizedBox(width: 8),
          Text(
            status,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
