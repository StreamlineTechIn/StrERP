import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:str_erp/members/MemberCheckAttendancePage.dart';
import 'package:str_erp/members/reedemcredit.dart';
import 'package:str_erp/members/work%20hours.dart';
import '../Manager/memberProfile.dart';
import '../TeamLead/dailyTaskTL.dart';
import 'package:permission_handler/permission_handler.dart';
import '../auth/Login.dart';
import 'package:str_erp/members/Tasks.dart'; // Ensure this path is correct
import 'package:str_erp/members/expenses.dart';
import 'package:str_erp/members/leaves.dart';
import 'package:str_erp/members/tickets.dart';
import 'MemberToDo.dart';
import 'YourProfile.dart';
import 'dailyTasks.dart';
import 'geoLocation.dart'; // Ensure this path is correct

class MemberHome extends StatefulWidget {
  MemberHome({super.key});

  @override
  _MemberHomeState createState() => _MemberHomeState();
}

class _MemberHomeState extends State<MemberHome> {
  User? user = FirebaseAuth.instance.currentUser;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  String? userName; // Store the user's name
  String? memberId;
  String? profileImageUrl;
  String? memberDocId; // Store the Firestore document ID
  final Color primaryColor = Color(0xFF6246EA); // Deep purple
  final Color secondaryColor = Color(0xFF2B2C34); // Dark gray
  final Color accentColor = Color(0xFFE45858); // Coral red
  final Color backgroundColor = Color(0xFFFFFFFE); // Off white
  final Color textColor = Color(0xFF2B2C34);
  List<Map<String, dynamic>> memberDetails = [];
  double finalCredit = 0.0;
  double _TempCredits = 0;
  double TempCredits = 0;
  double _totalWorkingHours = 0;
  final DateTime _startDate = DateTime.now().subtract(Duration(days: 6));
  bool _isLoading = false;
  Map<String, dynamic>? recentTask;
  bool isTaskLoading = true;
  String? taskErrorMessage;
  double mycredit = 0.0;
  Map<String, dynamic>? userData;

  Future<void> requestNotificationPermission() async {
    // Request notification permission
    PermissionStatus status = await Permission.notification.request();

    if (status.isGranted) {
      // Notification permission granted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification permissions granted')),
      );
    } else if (status.isDenied) {
      // Notification permission denied
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification permissions denied')),
      );
    } else if (status.isPermanentlyDenied) {
      // Notification permission permanently denied, open app settings
      openAppSettings();
    }
  }

  @override
  void initState() {
    super.initState();
    decideNextScreen();
    _fetchMemberDocIdAndName();
    fetchRecentTask(); // Fetch user's name and document ID
    _fetchAttendanceData();
    _fetchFinalCredits();

    requestNotificationPermission();
  }

  Future<void> decideNextScreen() async {
    QuerySnapshot snapshot = await _firestore
        .collection('members')
        .where('email', isEqualTo: user?.email)
        .get();

    Map<String, dynamic>? userData;

    if (snapshot.docs.isNotEmpty) {
      userData = snapshot.docs.first.data() as Map<String, dynamic>;
    }

    bool isProfileComplete = checkProfileCompletion(userData);

    if (!isProfileComplete) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (context) => YourProfilePage(email: user?.email)),
      );
    }
  }

  bool checkProfileCompletion(Map<String, dynamic>? userData) {
    List<String> fields = [
      'Name',
      'email',
      'PAN',
      'Bank_Acc_num',
      'IFSC',
      'adhar',
      'Number',
      'Gender',
      'DOB',
      'address',
      'Position',
      'StartDate',
      'Medical',
      'Authorized',
    ];

    for (String field in fields) {
      if (userData?[field] == null || userData![field].toString().isEmpty) {
        return false;
      }
    }

    return true;
  }

  //credit code start
  Future<void> _fetchAttendanceData() async {
    setState(() {
      _isLoading = true;
      _totalWorkingHours = 0.0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        _showErrorDialog("No user logged in");
        return;
      }

      // Find the most recent Monday
      DateTime now = DateTime.now();
      DateTime mostRecentMonday = now.subtract(Duration(days: now.weekday - 1));
      String mondayDateString =
          DateFormat('yyyy-MM-dd').format(mostRecentMonday);

      // Reference to the user's document in weeklyHours collection
      DocumentReference weeklyHoursDoc =
          _firestore.collection('weeklyHours').doc(user.email);

      // Initialize weekly hours data
      double totalHours = 0.0;
      double tempCredits = 0.0;
      double targetHours = 40.0;

      // Get the existing document
      DocumentSnapshot weeklyHoursSnapshot = await weeklyHoursDoc.get();

      // Prepare the update data
      Map<String, dynamic> updateData = {
        'dates': {
          mondayDateString: {
            'totalHours': 0.0,
            'tempCredits': 0.0,
            'targetHours': 40.0,
          }
        }
      };

      if (weeklyHoursSnapshot.exists) {
        // Retrieve existing data
        Map<String, dynamic> existingData =
            weeklyHoursSnapshot.data() as Map<String, dynamic>;
        Map<String, dynamic> existingDates =
            Map<String, dynamic>.from(existingData['dates'] ?? {});

        // Check if this week's data exists
        if (existingDates.containsKey(mondayDateString)) {
          totalHours =
              (existingDates[mondayDateString]['totalHours'] ?? 0.0).toDouble();
          tempCredits = (existingDates[mondayDateString]['tempCredits'] ?? 0.0)
              .toDouble();
          targetHours = (existingDates[mondayDateString]['targetHours'] ?? 40.0)
              .toDouble();
        }

        // Update the dates map
        existingDates[mondayDateString] = {
          'totalHours': totalHours,
          'tempCredits': tempCredits,
          'targetHours': targetHours,
        };

        updateData['dates'] = existingDates;
      }

      // Fetch today's attendance
      String todayDate = DateFormat('yyyy-MM-dd').format(now);
      DocumentSnapshot dailyAttendanceDoc =
          await _firestore.collection('memberAttendance').doc(todayDate).get();

      double todayHours = 0.0;
      if (dailyAttendanceDoc.exists) {
        Map<String, dynamic> data =
            dailyAttendanceDoc.data() as Map<String, dynamic>;

        if (data.containsKey('attendees') && data['attendees'] is Map) {
          Map<String, dynamic> attendees = data['attendees'];

          if (attendees.containsKey(user.email)) {
            Map<String, dynamic> userAttendance = attendees[user.email];

            String checkInStr = userAttendance['checkIn'] ?? '';
            String checkOutStr = userAttendance['checkOut'] ?? '';

            checkInStr = checkInStr.trim();
            checkOutStr = checkOutStr.trim();

            if (checkInStr.isNotEmpty && checkOutStr.isNotEmpty) {
              try {
                DateTime checkInTime = DateFormat('HH:mm').parse(checkInStr);
                DateTime checkOutTime = DateFormat('HH:mm').parse(checkOutStr);

                Duration workingDuration = checkOutTime.difference(checkInTime);
                todayHours = workingDuration.inMinutes / 60.0;

                // Add today's hours to total hours for this week
                totalHours += todayHours;

                // Update the specific week's data
                updateData['dates'][mondayDateString]['totalHours'] =
                    totalHours;
              } catch (e) {
                print("Error parsing time for $todayDate: $e");
              }
            }
          }
        }
      }

      // Calculate temporary credits
      double extraCredits = totalHours * 0.125;
      updateData['dates'][mondayDateString]['tempCredits'] = extraCredits;

      // Check if we've reached the end of the week
      DateTime endOfWeek = mostRecentMonday.add(Duration(days: 6));
      if (now.isAfter(endOfWeek)) {
        // Calculate extra hours
        double extraHours =
            totalHours > targetHours ? totalHours - targetHours : 0.0;
        updateData['dates'][mondayDateString]['extraHours'] = extraHours;
      }

      // Update the weekly hours document
      await weeklyHoursDoc.set(updateData, SetOptions(merge: true));
      await _updateUserWorkAndCredits(user.email!);

      setState(() {
        _totalWorkingHours = totalHours;
        _TempCredits = extraCredits;
      });
    } catch (e) {
      _showErrorDialog("Error fetching attendance data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserWorkAndCredits(String email) async {
    try {
      // Find the most recent Monday
      DateTime now = DateTime.now();
      DateTime mostRecentMonday = now.subtract(Duration(days: now.weekday - 1));
      String mondayDateString =
          DateFormat('yyyy-MM-dd').format(mostRecentMonday);

      // Query for the user's document in the members collection
      QuerySnapshot querySnapshot = await _firestore
          .collection('members')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentReference userDoc = querySnapshot.docs.first.reference;

        // Recalculate total hours from _fetchAttendanceData method
        double totalHours = _totalWorkingHours;

        // Update the user's document with weekly working hours
        await userDoc.update({
          'weeklyWorkingHours': totalHours.toDouble(),
        });

        // Query for existing weekly hours document
        QuerySnapshot weeklyHoursSnapshot = await _firestore
            .collection('weeklyHours')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (weeklyHoursSnapshot.docs.isNotEmpty) {
          DocumentReference existingDocRef =
              weeklyHoursSnapshot.docs.first.reference;

          DocumentSnapshot existingDoc = await existingDocRef.get();
          Map<String, dynamic> existingData =
              existingDoc.data() as Map<String, dynamic>;

          Map<String, dynamic> updatedData = existingData.containsKey('dates')
              ? Map<String, dynamic>.from(existingData['dates'])
              : {};

          updatedData[mondayDateString] = {
            'totalHours': totalHours.toDouble(),
            'targetHours': 40.0,
          };

          await existingDocRef
              .set({'dates': updatedData}, SetOptions(merge: true));
        } else {
          DocumentReference weeklyHoursDoc =
              _firestore.collection('weeklyHours').doc(email);

          await weeklyHoursDoc.set({
            'dates': {
              mondayDateString: {
                'totalHours': totalHours.toDouble(),
                'targetHours': 40.0,
              }
            }
          }, SetOptions(merge: true));
        }
      } else {
        _showErrorDialog("No user found with this email");
      }
    } catch (e) {
      print("Error updating work hours: $e");
      _showErrorDialog("Could not update work hours: $e");
    }
  }

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

  Future<void> fetchRecentTask() async {
    try {
      final QuerySnapshot userSnapshot = await _firestore
          .collection('members')
          .where('email', isEqualTo: user?.email)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception('No user found with the provided email.');
      }

      final DocumentSnapshot userDoc = userSnapshot.docs.first;
      final data = userDoc.data() as Map<String, dynamic>?;
      final tasks = List<Map<String, dynamic>>.from(data?['tasks'] ?? []);

      setState(() {
        recentTask = tasks.isNotEmpty ? tasks.last : null;
        isTaskLoading = false;
      });
    } catch (e) {
      setState(() {
        taskErrorMessage = 'Error fetching task';
        isTaskLoading = false;
      });
    }
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
          final userData = userDoc.data();

          setState(() {
            memberDocId = userDoc.id;
            memberId = userData.containsKey('memberId') ? userData['memberId'] : null;
            userName = userData['Name'] ?? 'User'; 
            profileImageUrl = userData['profileImageUrl'] ?? "";
          });
        } else {
          print('No member document found for email: $userEmail');
        }
      } catch (e) {
        print('Error fetching member document: $e');
      }
    } else {
      print('User email is null');
    }
  }

  Future<void> _fetchFinalCredits() async {
    try {
      // Fetch the current logged-in user's email
      String currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';

      if (currentUserEmail.isEmpty) {
        print('No user is logged in');
        return; // Exit if no user is logged in
      }

      // Fetch the document for the logged-in user
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('weeklyHours')
          .doc(currentUserEmail) // Using the email as the document ID
          .get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;

        // Check if the 'dates' field exists and is a Map
        if (data.containsKey('dates') && data['dates'] is Map) {
          Map<String, dynamic> dates = Map<String, dynamic>.from(data['dates']);

          if (dates.isNotEmpty) {
            // Find the most recent date in the 'dates' map
            String mostRecentDate = dates.keys.reduce(
                (a, b) => DateTime.parse(a).isAfter(DateTime.parse(b)) ? a : b);

            // Extract 'finalCredit' for the most recent date
            double finalCredit = dates[mostRecentDate]['finalCredit'] is num
                ? (dates[mostRecentDate]['finalCredit'] as num).toDouble()
                : 0.0;

            print("Final Credit for $currentUserEmail: $finalCredit");

            setState(() {
              mycredit = finalCredit; // Update the credit for the current user
              isLoading = false;
            });
          } else {
            print('No dates found for user: $currentUserEmail');
            setState(() {
              isLoading = false;
            });
          }
        } else {
          print(
              'No "dates" field found or invalid structure for user: $currentUserEmail');
          setState(() {
            isLoading = false;
          });
        }
      } else {
        print('Document not found for user: $currentUserEmail');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching finalCredits: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    try {
      await _auth.sendPasswordResetEmail(email: user?.email ?? '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to your email!')),
      );
    } catch (e) {
      print('Error resetting password: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reset password: $e')),
      );
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: ((context) => LoginPage())));
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.teal,
                backgroundColor,
              ],
            ),
          ),
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: Colors.teal),
                accountName: Text(
                  userName ?? 'User',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                accountEmail: Text(
                  user?.email ?? 'user@example.com',
                  style: GoogleFonts.montserrat(
                    color: Colors.white70,
                  ),
                ),
                currentAccountPicture: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  backgroundImage: profileImageUrl != null
                      ? NetworkImage(profileImageUrl!)
                      : null,
                  child: profileImageUrl == null
                      ? Icon(
                          Icons.person,
                          color: Colors.grey,
                          size: 40,
                        )
                      : null,
                ),
              ),
              ListTile(
                leading: Icon(Icons.home, color: Colors.white),
                title: Text(
                  'Home',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                },
              ),
              ListTile(
                leading: Icon(Icons.person, color: Colors.white),
                title: Text(
                  'Profile',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => YourProfilePage(
                        email: user?.email ??
                            '', // Replace with the email you want to pass
                      ),
                    ),
                  );
                },
              ),
              Spacer(),
              ListTile(
                leading: Icon(Icons.repeat, color: Colors.black),
                title: Text(
                  'Reset Password',
                  style: GoogleFonts.montserrat(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  _resetPassword();
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text(
                  'Logout',
                  style: GoogleFonts.montserrat(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  signOut();
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(
          'Home Page',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: backgroundColor,
          ),
        ),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(
              Icons.monetization_on, // Coins icon
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RedeemCreditsPage(
                    email: user?.email!, // Pass the correct member ID
                    finalCredits: mycredit, // Pass the dynamic value
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              mycredit.toStringAsFixed(2), // Display dynamic finalCredits
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.teal,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal,
              backgroundColor,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: isTaskLoading
                    ? Center(child: CircularProgressIndicator())
                    : taskErrorMessage != null
                        ? Text(taskErrorMessage!,
                            style: GoogleFonts.montserrat(color: Colors.red))
                        : recentTask == null
                            ? Text('No tasks found',
                                style: GoogleFonts.montserrat())
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person,
                                        color: primaryColor,
                                        size: 32,
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        // Wrap the Text widget in Expanded
                                        //
                                        child: Text(
                                          'Hello, ${userName ?? 'User'}',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal,
                                          ),
                                          overflow: TextOverflow
                                              .fade, // Ensure overflow is applied
                                          softWrap:
                                              false, // Prevent wrapping if that's the desired behavior
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.task_alt, color: Colors.teal),
                                      SizedBox(width: 8),
                                      Text(
                                        'Recent Task',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                      Spacer(),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      AdminTaskPage()));
                                        },
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.teal,
                                        ),
                                        child: const Text('View more'),
                                      )
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    recentTask?['title'] ?? 'Untitled Task',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    recentTask?['status'] ?? 'No status',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
              ),
              SizedBox(height: 20),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 3;
                    double childAspectRatio = 1.2;

                    // Adjust the grid layout based on screen width
                    if (constraints.maxWidth > 1200) {
                      crossAxisCount = 4;
                      childAspectRatio = 1.0;
                    } else if (constraints.maxWidth > 800) {
                      crossAxisCount = 3;
                      childAspectRatio = 1.1;
                    }

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: 8,
                      itemBuilder: (context, index) {
                        final tiles = [
                          _buildGridTile(
                            context: context,
                            icon: FontAwesomeIcons.checkToSlot,
                            label: 'Attendance',
                            backgroundColor: backgroundColor,
                            secondaryColor: secondaryColor,
                            primaryColor: primaryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AttendancePage()),
                              );
                            },
                          ),
                          _buildGridTile(
                            context: context,
                            icon: FontAwesomeIcons.checkToSlot,
                            label: 'Check Attendance',
                            backgroundColor: backgroundColor,
                            secondaryColor: secondaryColor,
                            primaryColor: primaryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => MemberCheckAttendancePage()),
                              );
                            },
                          ),
                          _buildGridTile(
                            context: context,
                            icon: FontAwesomeIcons.calendarDay,
                            label: 'Daily tasks',
                            backgroundColor: backgroundColor,
                            secondaryColor: secondaryColor,
                            primaryColor: primaryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => DailyTaskPage()),
                              );
                            },
                          ),
                          _buildGridTile(
                            context: context,
                            icon: FontAwesomeIcons.solidCalendarDays,
                            label: 'Admin tasks',
                            backgroundColor: backgroundColor,
                            secondaryColor: secondaryColor,
                            primaryColor: primaryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AdminTaskPage()),
                              );
                            },
                          ),
                          _buildGridTile(
                            context: context,
                            icon: FontAwesomeIcons.listCheck,
                            label: 'Tasks',
                            backgroundColor: backgroundColor,
                            secondaryColor: secondaryColor,
                            primaryColor: primaryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        AssignedTasksPage(userId: user?.email)),
                              );
                            },
                          ),
                          _buildGridTile(
                            context: context,
                            icon: FontAwesomeIcons.barsProgress,
                            label: 'Tickets',
                            backgroundColor: backgroundColor,
                            secondaryColor: secondaryColor,
                            primaryColor: primaryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => RaiseTicketPage(
                                        userEmail: user?.email)),
                              );
                            },
                          ),
                          _buildGridTile(
                            context: context,
                            icon: FontAwesomeIcons.barsProgress,
                            label: 'Leaves',
                            backgroundColor: backgroundColor,
                            secondaryColor: secondaryColor,
                            primaryColor: primaryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => LeaveApplicationPage(
                                        userEmail: user?.email)),
                              );
                            },
                          ),
                          _buildGridTile(
                            context: context,
                            icon: FontAwesomeIcons.checkToSlot,
                            label: 'To-Do',
                            backgroundColor: backgroundColor,
                            secondaryColor: secondaryColor,
                            primaryColor: primaryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => MembersTaskList()),
                              );
                            },
                          ),
                          _buildGridTile(
                            context: context,
                            icon: FontAwesomeIcons.repeat,
                            label: 'Reset password',
                            backgroundColor: backgroundColor,
                            secondaryColor: secondaryColor,
                            primaryColor: primaryColor,
                            onTap: () {
                              _resetPassword();
                            },
                          ),
                          /*_buildGridTile(
                            context: context,
                            icon: FontAwesomeIcons.checkToSlot,
                            label: 'working hr',
                            backgroundColor: backgroundColor,
                            secondaryColor: secondaryColor,
                            primaryColor: primaryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => WorkingHoursScreen()),
                              );
                            },
                          )*/
                        ];
                        return tiles[index];
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color secondaryColor,
    required Color primaryColor,
    required Function onTap,
  }) {
    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        padding: EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: secondaryColor.withOpacity(0.1),
              spreadRadius: 3,
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: primaryColor,
              size: 20,
            ),
            SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
