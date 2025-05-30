import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'memberProfile.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({Key? key}) : super(key: key);

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  List<String> memberEmails = [];
  bool isLoading = true;
  List<Map<String, dynamic>> memberDetails = [];
  @override
  void initState() {
    super.initState();
    _fetchMemberDetails();
  }

  Future<void> _fetchMemberDetails() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('members')
          .get();

      print('Total documents found: ${snapshot.docs.length}'); // Debug print

      List<Map<String, dynamic>> details = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;



        return {
          'email': data['email'] as String, // Assume 'email' is mandatory
          'profileImageUrl': data.containsKey('profileImageUrl') ? data['profileImageUrl'] as String? : null,
        };
      }).toList();

      setState(() {
        memberDetails = details;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching member details: $e');
      setState(() {
        isLoading = false;
      });
    }
  }


  Future<void> _deleteUserByEmail(String email) async {
    try {
      // Show confirmation dialog
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Confirm Deletion',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Are you sure you want to delete $email?',
              style: GoogleFonts.montserrat(),
            ),
            actions: [
              TextButton(
                child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: Text('Delete', style: TextStyle(color: Colors.red)),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      final userList = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email.trim());
      if (userList.isEmpty) {
        _showSnackBar('No user found with email: $email', isError: true);
        return;
      }

      User? userToDelete = (await FirebaseAuth.instance.fetchSignInMethodsForEmail(email)).isNotEmpty
          ? FirebaseAuth.instance.currentUser
          : null;

      if (userToDelete != null) {
        await userToDelete.delete();
        await FirebaseFirestore.instance.collection('members').doc(email).delete();

        setState(() {
          memberDetails.removeWhere((member) => member['email'] == email);
        });

        _showSnackBar('User $email deleted successfully');
      } else {
        _showSnackBar('User not found or not signed in', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error deleting user: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          "Members",
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchMemberDetails,
          ),
        ],
      ),
      body: Container(
        decoration:  BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal,
              Colors.white,
            ],
          ),
        ),
        child: isLoading
            ? Center(
          child: CircularProgressIndicator(
            color: Colors.teal,
          ),
        )
            : CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.all(16),
              sliver: memberDetails.isEmpty
                  ? SliverToBoxAdapter(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        "No member records found",
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    Map<String, dynamic> member = memberDetails[index];
                    String email = member['email'];
                    String? profileImageUrl = member['profileImageUrl'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Card(
                        color: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                         leading: CircleAvatar(
                        backgroundColor: Colors.teal[100],
                          child: profileImageUrl != null && profileImageUrl.isNotEmpty
                              ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: profileImageUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                  color: Colors.teal,
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (context, url, error) => Image.network(
                                'https://firebasestorage.googleapis.com/v0/b/strerp-6c7fb.firebasestorage.app/o/profile_images%2Flogo.png?alt=media&token=de02a465-40f9-40b9-acbd-4b760df65667',
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                              : ClipOval(
                            child: Image.network(
                              'https://placehold.co/600x400',
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        title: Text(
                            email,
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MemberProfilePage(email: email),
                              ),
                            );
                          },
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red[400],
                            ),
                            onPressed: () => _deleteUserByEmail(email),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: memberDetails.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}