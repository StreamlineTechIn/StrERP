import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'SalaryBreakdown.dart';

class SalaryPage extends StatefulWidget {
  @override
  State<SalaryPage> createState() => _SalaryPageState();
}

class _SalaryPageState extends State<SalaryPage> {
  List<Map<String, dynamic>> memberSalaries = [];
  double totalSalary = 0.0;
  final DateFormat timeFormat =
      DateFormat('HH:mm'); // Reuse this DateFormat instance
  bool isloading = false;

  @override
  void initState() {
    super.initState();
    fetchMemberSalaries();
  }

  bool isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  // Check if the workday is a full day
  bool isFullDay(String checkIn, String checkOut) {
    try {
      final checkInTime = timeFormat.parse(checkIn);
      final checkOutTime = timeFormat.parse(checkOut);

      final isValidTiming = checkInTime.isBefore(timeFormat.parse('10:15')) &&
          checkOutTime.isAfter(timeFormat.parse('17:59'));

      final workDuration = checkOutTime.difference(checkInTime);
      final isValidDuration =
          workDuration.inMinutes >= 464; // 7 hours 45 minutes

      return isValidTiming && isValidDuration;
    } catch (e) {
      print('Error calculating day type: $e');
      return false;
    }
  }

  // Check if the workday is a half day
// Check if the workday is a half day without considering the valid duration
  bool isHalfDay(String checkIn, String checkOut) {
    try {
      final checkInTime = timeFormat.parse(checkIn);
      final checkOutTime = timeFormat.parse(checkOut);

      // Check if the check-in is after 10:15 AM or check-out is before 5:59 PM
      final isInvalidTiming = checkInTime.isAfter(timeFormat.parse('10:15')) ||
          checkOutTime.isBefore(timeFormat.parse('17:59'));

      // Return true if it's a half-day (without duration validation)
      return isInvalidTiming;
    } catch (e) {
      print('Error calculating half day: $e');
      return false;
    }
  }
  Future<double> fetchAndUpdateAllSalaryCredits(String email, double dailySalary) async {
    print('Entered credit function for email: $email');
    try {
      final creditDoc = await FirebaseFirestore.instance
          .collection('weeklyHours')
          .doc(email)
          .get();

      if (!creditDoc.exists) {
        print('Document does not exist for email: $email');
        return 0.0;
      }

      final data = creditDoc.data();
      if (data == null || !data.containsKey('dates')) {
        print('No "dates" field in document for email: $email');
        return 0.0;
      }

      final datesMap = data['dates'] as Map<String, dynamic>;
      double totalEarnings = 0.0;

      // Iterate through all dates and calculate total salary credits
      datesMap.forEach((dateKey, dateData) {
        if (dateData is Map<String, dynamic> && dateData.containsKey('salarycredit')) {
          double salarycredit = (dateData['salarycredit'] ?? 0.0).toDouble();
          totalEarnings += salarycredit * dailySalary;

          // Reset salarycredit for this date
          dateData['salarycredit'] = 0;
        }
      });

      print('Total calculated earnings: $totalEarnings');

      // Update the Firestore document with the reset salary credits
      await FirebaseFirestore.instance
          .collection('weeklyHours')
          .doc(email)
          .update({'dates': datesMap});

      return totalEarnings;
    } catch (e) {
      print('Error fetching salary credits for email $email: $e');
      return 0.0;
    }
  }

  Future<void> fetchMemberSalaries() async {
    setState(() {
      isloading = true;
    });
    try {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final firstDayOfMonth = lastMonth;
      final lastDayOfMonth = DateTime(now.year, now.month, 0);

      final membersSnapshot = await FirebaseFirestore.instance.collection('members').get();

      double totalMonthSalary = 0.0;
      List<Map<String, dynamic>> salaries = [];

      for (var memberDoc in membersSnapshot.docs) {
        Map<String, dynamic> memberData = memberDoc.data() as Map<String, dynamic>;

        String? name = memberData['name'];
        String? email = memberData['email'];
        String? empId = memberData['memberId'];
        String? currentSalary = memberData['Current Salary'];
        String? Acc_Num = memberData['Bank_Acc_num'] ?? 'N/A';
        String? IFSC = memberData['IFSC'] ?? 'N/A';


        if (currentSalary == null) continue;

        double monthlySalary = double.tryParse(currentSalary) ?? 0.0;
        double dailySalary = monthlySalary / 23; // Calculate daily salary

        // Fetch and calculate additional earnings from salarycredit
        print(email);
        double additionalEarnings = await fetchAndUpdateAllSalaryCredits(email!, dailySalary);

        // Calculate working days
        int fullDays = 0;
        int halfDays = 0;

        for (var date = firstDayOfMonth;
        date.isBefore(lastDayOfMonth.add(Duration(days: 1)));
        date = date.add(Duration(days: 1))) {
          if (isWeekend(date)) continue;

          String formattedDate = DateFormat('yyyy-M-d').format(date);
          final attendanceDoc = await FirebaseFirestore.instance
              .collection('memberAttendance')
              .doc(formattedDate)
              .get();

          if (attendanceDoc.exists) {
            Map<String, dynamic>? attendanceData = attendanceDoc.data() as Map<String, dynamic>?;
            if (attendanceData != null && attendanceData['attendees']?[email] != null) {
              var memberAttendance = attendanceData['attendees'][email];
              String? checkIn = memberAttendance['checkIn'];
              String? checkOut = memberAttendance['checkOut'];

              if (checkIn != null && checkOut != null) {
                if (isFullDay(checkIn, checkOut)) {
                  fullDays++;
                } else if (isHalfDay(checkIn, checkOut)) {
                  halfDays++;
                }
              }
            }
          }
        }

        // Calculate total salary including attendance and additional earnings
        double totalWorkingDays = fullDays + (halfDays * 0.5);
        double regularSalary = (monthlySalary / 23) * totalWorkingDays;
        double calculatedSalary = regularSalary + additionalEarnings;

        salaries.add({
          'name': name ?? 'Unknown',
          'salary': calculatedSalary,
          'regularSalary': regularSalary,
          'additionalEarnings': additionalEarnings,
          'EmpId': empId ?? 'N/A',
          'Email': email,
          'Acc_Num': Acc_Num,
          'IFSC': IFSC,
          'fullDays': fullDays,
          'halfDays': halfDays,
          'monthlySalary': monthlySalary,
        });

        totalMonthSalary += calculatedSalary;
      }

      setState(() {
        memberSalaries = salaries;
        totalSalary = totalMonthSalary;
        isloading = false;
      });
    } catch (e) {
      print('Error fetching salaries: $e');
      setState(() {
        isloading = false;
      });
    }
  }


  void payAllSalaries() {
    // Logic to handle "Pay All" action
    print('Paying all salaries...');
    // Add your payment handling logic here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary Overview'),
        backgroundColor: Colors.teal,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal,
              const Color(0xFFFFFFFE), // Off white
            ],
          ),
        ),
        child: isloading
            ? Center(
          child: SizedBox(
            height: 250, // Adjusted height for better balance
            width: 300,  // Added width for a consistent card size
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0), // Rounded corners for modern look
              ),
              color: Colors.white,
              elevation: 4, // Adds a shadow for depth
              child: Padding(
                padding: const EdgeInsets.all(16.0), // Increased padding for better spacing
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center, // Ensures content is centered
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3, // Slimmer progress indicator
                      color: Colors.blueAccent, // Updated color for better visibility
                    ),
                    SizedBox(height: 20), // Spacing between indicator and text
                    Text(
                      'Loading Salaries...',
                      style: GoogleFonts.montserrat(
                        fontSize: 18, // Increased font size for better readability
                        fontWeight: FontWeight.bold,
                        color: Colors.black87, // Slightly muted black for better contrast
                      ),
                      textAlign: TextAlign.center, // Centers the text
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Salary to Pay',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '₹${totalSalary.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Member Salaries',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: memberSalaries.length,
                      itemBuilder: (context, index) {
                        final member = memberSalaries[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(10.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade300,
                                  blurRadius: 10.0,
                                  spreadRadius: 2.0,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const FaIcon(
                                          FontAwesomeIcons.userTie,
                                          color: Colors.teal,
                                        ),
                                        const SizedBox(width: 10.0),
                                        Text(
                                          member['name'],
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 18.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '₹${member['salary'].toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.teal,
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(
                                    color: Colors.grey, thickness: 1.0),
                                const SizedBox(height: 8.0),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Employee ID:',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      member['EmpId'],
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Account Number:',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      member['Acc_Num'],
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'IFSC code:',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      member['IFSC'],
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8.0),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Email:',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        member['Email'].toString(),
                                        textAlign: TextAlign.right,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    buildSalarySlipButton(member),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 16.0),
                    color: Colors.teal,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: payAllSalaries,
                      child: Text(
                        'Pay All',
                        style: GoogleFonts.montserrat(
                          color: Colors.teal,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget buildSalarySlipButton(Map<String, dynamic> member) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SalarySlipPage(memberData: member),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(FontAwesomeIcons.fileInvoiceDollar, size: 16),
          const SizedBox(width: 8),
          Text(
            'Salary Slip',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
