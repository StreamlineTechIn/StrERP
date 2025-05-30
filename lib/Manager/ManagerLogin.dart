import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/Login.dart';


import 'ManagerHome.dart'; // Import your MemberHomePage

class ManagerLogin extends StatefulWidget {
  @override
  _ManagerLoginState createState() => _ManagerLoginState();
}

class _ManagerLoginState extends State<ManagerLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isPasswordVisible = false;
  List<String> teamLeads = [];

  @override
  void initState() {
    super.initState();
    _fetchTeamLeads();
  }

  Future<void> _fetchTeamLeads() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('managers')
          .doc('accounts')
          .get();

      if (doc.exists) {
        setState(() {
          teamLeads = List<String>.from(doc['users']);
          for (int i = 0; i < teamLeads.length; i++) {
            // Changed <= to <
            print(teamLeads[i]);
          }
        });
      }
    } catch (e) {
      print('Error fetching team leads: $e');
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (teamLeads.contains(email)) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => ManagerHome()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Only managers allowed to login')));
      }
    } catch (e) {
      print('Error: $e');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black,
                  Colors.blueGrey.shade900,
                  Colors.deepPurple.shade900,
                  Colors.indigo.shade900
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: GlassmorphicContainer(
          constraints: BoxConstraints(
          maxWidth: 400, // Specify your maximum width here
          ),
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.width > 600
                  ? 450
                  : MediaQuery.of(context).size.height * 0.75,
              borderRadius: 20,
              blur: 20,
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
                        "Manager's Login",
                        style: TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.email, color: Colors.white),
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
                        controller: _passwordController,
                        style: TextStyle(color: Colors.white),
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock, color: Colors.white),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
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
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          elevation: 1,
                          shadowColor: Colors.white,
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
                          'Login',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      TextButton(onPressed: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>LoginPage()));
                      },
                          child: Text("regular Login"))
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
