import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:str_erp/TeamLead/Finances.dart';
import 'package:str_erp/TeamLead/ListAttendance.dart';
import 'package:str_erp/TeamLead/TLTODOList.dart';
import 'package:str_erp/TeamLead/TicketManager.dart';
import 'package:str_erp/TeamLead/invoices.dart';
import 'package:str_erp/TeamLead/leavesManager.dart';
import 'package:str_erp/TeamLead/remotelocation.dart';
import 'package:str_erp/TeamLead/taskManager.dart';
import 'package:str_erp/TeamLead/userCreditList.dart';
import '../Manager/users.dart';
import '../auth/Login.dart';
import '../members/showExpenses.dart';
import 'Leads.dart';
import 'LocationCalendar.dart';
import 'MemberLocationMapPage.dart';
import 'clients.dart';
import 'dailyTaskTL.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = false;
  User? user = FirebaseAuth.instance.currentUser;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _recentLeave;

  String? _errorMessage;
  String? _successMessage;
  final Color primaryColor = Color(0xFF6246EA); // Deep purple
  final Color secondaryColor = Color(0xFF2B2C34); // Dark gray
  final Color accentColor = Color(0xFFE45858); // Coral red
  final Color backgroundColor = Color(0xFFFFFFFE); // Off white
  final Color textColor = Color(0xFF2B2C34);
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

  Future<void> createDocumentIfNotExists() async {
    try {
      // Get the current user
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        String userEmail = user.email!;

        // Reference to the document in the TLTasks collection
        DocumentReference docRef =
            FirebaseFirestore.instance.collection('TLTasks').doc(userEmail);

        // Check if the document exists
        DocumentSnapshot docSnapshot = await docRef.get();

        if (!docSnapshot.exists) {
          // If the document does not exist, create it with any initial data you want
          await docRef.set({
            'email': userEmail,
            // Add any other initial fields here
          });
        }
      }
    } catch (e) {
      print('Error creating document: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: ((context) => LoginPage())));
      // Navigate to the login page after signing out
    } catch (e) {
      print('Sign out error: $e');
      // Optionally, show an error message to the user
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    createDocumentIfNotExists();
    _fetchRecentLeave();
  }

  Future<void> _fetchRecentLeave() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot membersSnapshot =
      await FirebaseFirestore.instance.collection('members').get();

      List<Map<String, dynamic>> allLeaves = [];

      for (var memberDoc in membersSnapshot.docs) {
        final data = memberDoc.data() as Map<String, dynamic>?;
        final userLeaveApplications = data?['leaveApplications'] as List<dynamic>? ?? [];

        for (var application in userLeaveApplications) {
          allLeaves.add({
            ...application as Map<String, dynamic>,
            'raisedBy': data?['email'] ?? 'Unknown',
            'memberId': memberDoc.id,
          });
        }
      }

      // Sort by creation date and get most recent
      if (allLeaves.isNotEmpty) {
        allLeaves.sort((a, b) {
          final aDate = (a['createdAt'] as Timestamp).toDate();
          final bDate = (b['createdAt'] as Timestamp).toDate();
          return bDate.compareTo(aDate);
        });

        setState(() {
          _recentLeave = allLeaves.first;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching recent leave: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildRecentLeaveCard() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_recentLeave == null ||_recentLeave!['status']=='Rejected'|| _recentLeave!['status']=='Approved') {
      return Container();
    }

    final startDate = (_recentLeave!['startDate'] as Timestamp).toDate();
    final endDate = (_recentLeave!['endDate'] as Timestamp).toDate();
    final status = _recentLeave!['status'];
    final raisedBy = _recentLeave!['raisedBy'];

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Leave Request',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'Pending'
                      ? Colors.orange
                      : status == 'Approved'
                      ? Colors.green
                      : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'By: ${raisedBy.toString().split('@')[0]}',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(endDate)}',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AdminLeaveManagementPage()),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.teal.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'View All Leaves',
              style: GoogleFonts.montserrat(
                color: Colors.teal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: backgroundColor,
          ),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
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
              SizedBox(height: 50,),
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
                splashColor: Colors.white,
                leading: Icon(Icons.attach_money, color: Colors.white),
                title: Text(
                  'Finances',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FinancePage(
                        // Replace with the email you want to pass
                      ),
                    ),
                  );
                },
              ),

              ListTile(
                splashColor: Colors.white,
                leading: Icon(Icons.work, color: Colors.white),
                title: Text(
                  'leads',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LeadsPage(
                        // Replace with the email you want to pass
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                splashColor: Colors.white,
                leading: Icon(Icons.person_pin_rounded, color: Colors.white),
                title: Text(
                  'Clients',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClientsPage(
                        // Replace with the email you want to pass
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                splashColor: Colors.white,
                leading: Icon(Icons.request_page_rounded, color: Colors.white),
                title: Text(
                  'invoices',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvoicesPage(
                        // Replace with the email you want to pass
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                splashColor: Colors.white,
                leading: Icon(Icons.request_page_rounded, color: Colors.white),
                title: Text(
                  'quotes',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LeadsPage(
                        // Replace with the email you want to pass
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
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.only(top: 10, left: 8,right: 8,bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: primaryColor,
                          size: 32,
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Welcome, ${user?.email?.split('@')[0]}',
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),

                      ],
                    ),
                    _buildRecentLeaveCard(),
                  ],
                ),
              ),

              SizedBox(height: 24),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  return GridView(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 1.1,
                    ),
                    children: [
                      _buildGridTile(
                        icon: FontAwesomeIcons.userPlus,
                        label: 'Add Member',
                        onTap: () => _showAddMemberDialog(context),
                      ),
                      _buildGridTile(
                        icon: FontAwesomeIcons.user,
                        label: 'Members',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MembersPage()),
                          );
                        },
                      ),
                      _buildGridTile(
                        icon: FontAwesomeIcons.locationPin,
                        label: 'Location History',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => CalendarPage()),
                          );
                        },
                      ),
                      _buildGridTile(
                        icon: FontAwesomeIcons.clipboardList,
                        label: 'Attendance',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AdminAttendancePage()),
                          );
                        },
                      ),
                      _buildGridTile(
                        icon: FontAwesomeIcons.clipboardList,
                        label: 'Remote Request',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => TeamLeadApprovalPage()),
                          );
                        },
                      ),
                      _buildGridTile(
                        icon: FontAwesomeIcons.solidCalendarDays,
                        label: 'Daily tasks',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AdminTaskPage()),
                          );
                        },
                      ),
                      _buildGridTile(
                        icon: FontAwesomeIcons.calendarWeek,
                        label: 'leaves',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    AdminLeaveManagementPage()),
                          );
                        },
                      ),

                      // _buildGridTile(
                      //   icon: FontAwesomeIcons.cashRegister,
                      //   label: 'Your Tasks',
                      //
                      //   onTap: () {
                      //     Navigator.push(
                      //       context,
                      //       MaterialPageRoute(
                      //           builder: (context) => TLAssignedTasks()),
                      //     );
                      //   },
                      // ),
                      _buildGridTile(
                        icon: FontAwesomeIcons.list,
                        label: 'Tasks',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => TaskManagerPage()),
                          );
                        },
                      ),
                      // _buildGridTile(
                      //   icon: FontAwesomeIcons.ticket,
                      //   label: 'Raise ticket',
                      //
                      //   onTap: () {
                      //     Navigator.push(
                      //       context,
                      //       MaterialPageRoute(
                      //           builder: (context) =>
                      //               TLRaiseTicket(userEmail: user?.email)),
                      //     );
                      //   },
                      // ),
                      _buildGridTile(
                        icon: FontAwesomeIcons.listCheck,
                        label: 'To-Do List',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => TLTODOList()),
                          );
                        },
                      ),
                      _buildGridTile(
                        icon: FontAwesomeIcons.barsProgress,
                        label: 'Tickets',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AdminTicketPage()),
                          );
                        },
                      ),
                      _buildGridTile(
                        icon: FontAwesomeIcons.cashRegister,
                        label: 'Expenses',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ExpenseListPage()),
                          );
                        },
                      ),
                      _buildGridTile(
                        icon: FontAwesomeIcons.coins,
                        label: 'View Credit',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MembersCreditList()),
                          );
                        },
                      ),

                      _buildGridTile(
                        icon: FontAwesomeIcons.repeat,
                        label: 'Reset Password',
                        onTap: () {
                          _resetPassword();
                        },
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: secondaryColor.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: primaryColor,
              ),
            ),
            SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: GlassmorphicContainer(
                width: MediaQuery.of(context).size.width * 0.85,
                height: _isLoading ? 300 : 400,
                borderRadius: 20,
                blur: 5,
                alignment: Alignment.center,
                border: 2,
                linearGradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderGradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.5),
                    Colors.white.withOpacity(0.5),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Add Member',
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 20),
                        if (_isLoading) ...[
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text(
                            'Adding member...',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ] else ...[
                          TextField(
                            controller: nameController,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Name',
                              labelStyle: TextStyle(color: Colors.white),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.teal),
                              ),
                            ),
                          ),
                          TextField(
                            controller: emailController,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: Colors.white),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.teal),
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          TextField(
                            controller: passwordController,
                            style: TextStyle(color: Colors.white),
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(color: Colors.white),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.teal),
                              ),
                            ),
                          ),
                          SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: () async {
                              // Validate inputs
                              String name = nameController.text.trim();
                              String email = emailController.text.trim();
                              String password = passwordController.text.trim();

                              // Input validation
                              if (name.isEmpty) {
                                setState(() {
                                  _errorMessage = 'Name cannot be empty';
                                });
                                return;
                              }

                              if (email.isEmpty || !_isValidEmail(email)) {
                                setState(() {
                                  _errorMessage = 'Please enter a valid email address';
                                });
                                return;
                              }

                              if (password.length < 6) {
                                setState(() {
                                  _errorMessage = 'Password must be at least 6 characters long';
                                });
                                return;
                              }

                              setState(() {
                                _isLoading = true;
                                _errorMessage = null;
                                _successMessage = null;
                              });

                              try {
                                // Use createUserWithEmailAndPassword with the current signed-in user's credentials
                                UserCredential userCredential = await FirebaseAuth.instance
                                    .createUserWithEmailAndPassword(
                                    email: email,
                                    password: password
                                );

                                // Immediately delete the automatically created user session
                                await userCredential.user?.delete();

                                // Generate memberId with improved logic
                                String memberId = _generateMemberId(name);

                                // Add the user to Firestore
                                await _firestore.collection('members').add({
                                  'email': email,
                                  'Name': name,
                                  'memberId': memberId,
                                  'TL': user?.email, // Assuming 'user' is the current admin/team lead
                                });

                                // Clear the fields and show success message
                                emailController.clear();
                                nameController.clear();
                                passwordController.clear();
                                setState(() {
                                  _successMessage = 'Member added successfully!';
                                });

                                Future.delayed(Duration(seconds: 2), () {
                                  Navigator.of(context).pop();
                                });
                              } on FirebaseAuthException catch (e) {
                                setState(() {
                                  switch (e.code) {
                                    case 'weak-password':
                                      _errorMessage = 'The password is too weak.';
                                      break;
                                    case 'email-already-in-use':
                                      _errorMessage = 'An account already exists with this email.';
                                      break;
                                    case 'invalid-email':
                                      _errorMessage = 'The email address is not valid.';
                                      break;
                                    default:
                                      _errorMessage = 'Authentication error: ${e.message}';
                                  }
                                });
                              } catch (e) {
                                setState(() {
                                  _errorMessage = 'An unexpected error occurred: $e';
                                });
                              } finally {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              'Add',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          if (_successMessage != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                _successMessage!,
                                style: TextStyle(color: Colors.green),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    _errorMessage = null;
    _successMessage = null;
  }


// Helper method to generate memberId
  String _generateMemberId(String name) {
    // Remove any whitespace and convert to lowercase
    name = name.trim().toLowerCase();

    // If name is less than 4 characters, pad with random letters
    if (name.length < 4) {
      // Use first characters and add random letters to make it at least 4 chars
      String prefix = name;
      while (prefix.length < 4) {
        prefix += String.fromCharCode(97 + Random().nextInt(26)); // Add random lowercase letter
      }
      name = prefix;
    }

    // Take first 4 characters of the name
    String namePrefix = name.substring(0, 4);

    // Generate a random 5-digit number
    String randomNumber = (10000 + Random().nextInt(90000)).toString();

    return namePrefix + randomNumber;
  }

// Email validation helper method
  bool _isValidEmail(String email) {
    // Basic email validation regex
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(email);
  }

}
