import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WorkingHoursScreen extends StatefulWidget {
  @override
  _WorkingHoursScreenState createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  double _totalWorkingHours = 0;
  double _TempCredits = 0; // New variable to track extra credits
  Map<String, dynamic> _attendanceData = {};
  DateTime _startDate = DateTime.now().subtract(Duration(days: 6));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchAttendanceData();
  }

  Future<void> _fetchAttendanceData() async {
    setState(() {
      _isLoading = true;
      _totalWorkingHours = 0;
      _TempCredits = 0;
      _attendanceData.clear();
    });

    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        _showErrorDialog("No user logged in");
        return;
      }

      // Get the last 7 days' dates
      List<String> datesToFetch = [];
      for (int i = 0; i < 7; i++) {
        DateTime date = _startDate.add(Duration(days: i));
        datesToFetch.add(DateFormat('yyyy-MM-d').format(date));
      }

      double totalHours = 0;

      // Loop through each date and fetch attendance data
      for (String date in datesToFetch) {
        DocumentSnapshot doc = await _firestore
            .collection('memberAttendance')
            .doc(date)
            .get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          if (data.containsKey('attendees') && data['attendees'] is Map) {
            Map<String, dynamic> attendees = data['attendees'];

            if (attendees.containsKey(user.email)) {
              Map<String, dynamic> userAttendance = attendees[user.email];

              String checkInStr = userAttendance['checkIn'] ?? '';
              String checkOutStr = userAttendance['checkOut'] ?? '';

              if (checkInStr.isNotEmpty && checkOutStr.isNotEmpty) {
                DateTime checkInTime = DateFormat('HH:mm').parse(checkInStr);
                DateTime checkOutTime = DateFormat('HH:mm').parse(checkOutStr);

                Duration workingDuration = checkOutTime.difference(checkInTime);
                double hoursWorked = workingDuration.inMinutes / 60.0;

                totalHours += hoursWorked;

                setState(() {
                  _attendanceData[date] = {
                    'checkIn': checkInStr,
                    'checkOut': checkOutStr,
                    'hoursWorked': hoursWorked,
                  };
                });
              }
            }
          }
        }
      }

      // Calculate extra credits
      double extraHours = totalHours > 40 ? totalHours - 40 : 0;
      double TempCredits = extraHours * 0.125;

      // Update user's credits in Firestore
      if (TempCredits > 0) {
        await _updateUserCredits(user.email!, TempCredits);
      }

      setState(() {
        _totalWorkingHours = totalHours;
        _TempCredits = TempCredits;
      });
    } catch (e) {
      _showErrorDialog("Error fetching attendance data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // New method to update user credits
  Future<void> _updateUserCredits(String email, double TempCredits) async {
    try {
      // Query to find the document where the email matches the current user's email
      QuerySnapshot querySnapshot = await _firestore
          .collection('members')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Get the first matching document
        DocumentReference userDoc = querySnapshot.docs.first.reference;

        // Update or add the credit field
        await userDoc.update({
          'credit': FieldValue.increment(TempCredits)
        });
      } else {
        _showErrorDialog("No user found with this email");
      }
    } catch (e) {
      print("Error updating credits: $e");
      _showErrorDialog("Could not update credits: $e");
    }
  }
  // Existing error dialog method...
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: Text('Okay'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Working Hours for the Last 7 Days'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Working Hours for the Last 7 Days: ${_totalWorkingHours.toStringAsFixed(2)} hours',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Extra Credits Earned: ${_TempCredits.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 16, color: Colors.green),
            ),
            SizedBox(height: 20),

          ],
        ),
      ),
    );
  }

  // Existing attendance list building method...

}