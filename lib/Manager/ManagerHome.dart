import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:str_erp/Manager/TLticketView.dart';
import 'package:str_erp/members/geoLocation.dart';
import 'package:str_erp/members/tickets.dart';

import '../TeamLead/ListAttendance.dart';
import '../TeamLead/TicketManager.dart';
import '../TeamLead/taskManager.dart';

import '../auth/Login.dart';
import '../members/expenses.dart';
import 'TLtasks.dart';


class ManagerHome extends StatefulWidget {
  ManagerHome({super.key});

  @override
  _ManagerHomeState createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  bool _isLoading = false;
  User? user = FirebaseAuth.instance.currentUser;
  String? _errorMessage;
  String? _successMessage;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: ((context) => LoginPage())));
    } catch (e) {
      print('Sign out error: $e');
    }
  }


  Future<void> _resetPassword() async {


    try {
      await _auth.sendPasswordResetEmail(email: user?.email??'');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to your email!')),

      );
    } catch
    (e) {
      print('Error resetting password: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reset password: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manager'),
        backgroundColor: Colors.deepPurple.shade700,
        actions: [
          IconButton(icon: Icon(Icons.logout), onPressed: signOut),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Hello, ${user?.email}',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 24,
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                int crossAxisCount = 2;
                double childAspectRatio = 1.2;

                if (constraints.maxWidth > 1200) {
                  crossAxisCount = 4;
                  childAspectRatio = 1.0;
                } else if (constraints.maxWidth > 800) {
                  crossAxisCount = 3;
                  childAspectRatio = 1.1;
                }

                return GridView(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                    childAspectRatio: childAspectRatio,
                  ),
                  children: [
                    _buildGridTile(
                      icon: FontAwesomeIcons.userPlus,
                      label: 'Add Member',
                      color: Colors.black,
                      onTap: () => _showAddMemberDialog(context),
                    ),
                    _buildGridTile(
                      icon: FontAwesomeIcons.clipboardList,
                      label: 'Attendance',
                      color: Colors.black,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => AttendancePage()),
                        );
                      },
                    ),
                    _buildGridTile(
                      icon: FontAwesomeIcons.list,
                      label: 'Tasks',
                      color: Colors.black,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => TaskManagerPage()),
                        );
                      },
                    ),
                    _buildGridTile(
                      icon: FontAwesomeIcons.barsProgress,
                      label: 'Tickets',
                      color: Colors.black,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => RaiseTicketPage(userEmail: user?.email)),
                        );
                      },
                    ),
                    _buildGridTile(
                      icon: FontAwesomeIcons.cashRegister,
                      label: 'TL tickets',
                      color: Colors.black,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => viewTLTickets()),
                        );
                      },
                    ),
                    _buildGridTile(
                      icon: FontAwesomeIcons.cashRegister,
                      label: 'Expenses',
                      color: Colors.black,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ExpenseTrackerPage()),
                        );
                      },
                    ),

                    _buildGridTile(
                      icon: FontAwesomeIcons.repeat,
                      label: 'Reset Password',
                      color: Colors.black,
                      onTap: () {
                     _resetPassword();
                      },
                    )
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        color: color,
        child: AspectRatio(
          aspectRatio: 1.2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: MediaQuery.of(context).size.width < 600 ? 30 : 40,
                  color: Colors.deepPurple.shade700,
                ),
                SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade300,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
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
                            controller: emailController,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: Colors.white),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue),
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
                                borderSide: BorderSide(color: Colors.blue),
                              ),
                            ),
                          ),
                          SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                _isLoading = true;
                                _errorMessage = null;
                                _successMessage = null;
                              });

                              try {
                                UserCredential userCredential =
                                await _auth.createUserWithEmailAndPassword(
                                  email: emailController.text.trim(),
                                  password: passwordController.text.trim(),
                                );

                                // Add the user to Firestore
                                await _firestore.collection('members').add({
                                  'email': userCredential.user?.email,
                                });

                                // Clear the fields and show success message
                                emailController.clear();
                                passwordController.clear();
                                setState(() {
                                  _successMessage =
                                  'Member added successfully!';
                                });

                                Future.delayed(Duration(seconds: 2), () {
                                  Navigator.of(context).pop();
                                });
                              } catch (e) {
                                setState(() {
                                  _errorMessage = 'Error: $e';
                                });
                              } finally {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple.shade700,
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
  }
}
