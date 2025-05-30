import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MembersCreditList extends StatefulWidget {
  const MembersCreditList({Key? key}) : super(key: key);

  @override
  State<MembersCreditList> createState() => _MembersCreditListState();
}

class _MembersCreditListState extends State<MembersCreditList> {
  List<Map<String, dynamic>> memberDetails = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMemberDetails();
    _fetchTempCredits();
  }

  // Fetch tempCredits for each member from the 'weeklyHours' collection
  Future<void> _fetchTempCredits() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('weeklyHours')
          .get();

      print('Total documents found: ${snapshot.docs.length}');

      // Fetch tempCredits for each user and add it to the memberDetails list
      List<Map<String, dynamic>> updatedMemberDetails = memberDetails.map((user) {
        double tempCredits = 0.0;
        final userEmail = user['email'];

        // Find tempCredits for the current user
        snapshot.docs.forEach((doc) {
          if (doc.id == userEmail) {
            final data = doc.data() as Map<String, dynamic>;
            if (data.containsKey('dates') && data['dates'] is Map) {
              Map<String, dynamic> dates = Map<String, dynamic>.from(data['dates']);
              if (dates.isNotEmpty) {
                // Find the most recent date
                String mostRecentDate = dates.keys.reduce((a, b) =>
                DateTime.parse(a).isAfter(DateTime.parse(b)) ? a : b);
                // Extract tempCredits for the most recent date
                tempCredits = dates[mostRecentDate]['tempCredits'] is num
                    ? (dates[mostRecentDate]['tempCredits'] as num).toDouble()
                    : 0.0;
              }
            }
          }
        });

        // Add tempCredits to the user's details
        user['tempCredits'] = tempCredits;
        return user;
      }).toList();

      // Update the state with the updated member details
      setState(() {
        memberDetails = updatedMemberDetails;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching tempCredits: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Fetch member details from the 'members' collection
  Future<void> _fetchMemberDetails() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('members')
          .get();

      print('Total documents found: ${snapshot.docs.length}');

      List<Map<String, dynamic>> details = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'documentId': doc.id, // Add document ID for Firestore updates
          'name': data.containsKey('name') ? data['name'] as String? : null,
          'email': data['email'] as String,
          'memberId': data.containsKey('memberId') ? data['memberId'] as String? : null,
          'tempCredits': 0.0, // Initialize tempCredits with 0.0
        };
      }).toList();

      setState(() {
        memberDetails = details;
        isLoading = false;
      });

      // After fetching member details, fetch tempCredits
      _fetchTempCredits();
    } catch (e) {
      print('Error fetching user details: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Method to handle Right Tick (Confirm Credits)
  Future<void> _handleRightTick(Map<String, dynamic> user) async {
    try {
      DocumentReference docRef = FirebaseFirestore.instance
          .collection('weeklyHours')
          .doc(user['email']);

      DocumentSnapshot snapshot = await docRef.get();
      if (!snapshot.exists) {
        throw Exception('Document does not exist');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      if (!data.containsKey('dates') || data['dates'] is! Map) {
        throw Exception('Invalid Firestore structure');
      }

      Map<String, dynamic> dates = Map<String, dynamic>.from(data['dates']);
      if (dates.isEmpty) {
        throw Exception('No dates available for processing');
      }

      String mostRecentDate = dates.keys.reduce((a, b) =>
      DateTime.parse(a).isAfter(DateTime.parse(b)) ? a : b);

      if (dates[mostRecentDate].containsKey('tempCredits')) {
        double tempCredits = dates[mostRecentDate]['tempCredits'];
        dates[mostRecentDate]['finalCredit'] = tempCredits;
        dates[mostRecentDate].remove('tempCredits');
      }

      await docRef.update({'dates': dates});

      _fetchMemberDetails();
      _showSnackBar('Credits confirmed for ${user['email']}');
    } catch (e) {
      print('Error confirming credits: $e');
      _showSnackBar('Failed to confirm credits', isError: true);
    }
  }

  Future<void> _handleWrongTick(Map<String, dynamic> user) async {
    try {
      DocumentReference docRef = FirebaseFirestore.instance
          .collection('weeklyHours')
          .doc(user['email']);

      DocumentSnapshot snapshot = await docRef.get();
      if (!snapshot.exists) {
        throw Exception('Document does not exist');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      if (!data.containsKey('dates') || data['dates'] is! Map) {
        throw Exception('Invalid Firestore structure');
      }

      Map<String, dynamic> dates = Map<String, dynamic>.from(data['dates']);
      if (dates.isEmpty) {
        throw Exception('No dates available for processing');
      }

      String mostRecentDate = dates.keys.reduce((a, b) =>
      DateTime.parse(a).isAfter(DateTime.parse(b)) ? a : b);

      if (dates[mostRecentDate].containsKey('tempCredits')) {
        dates[mostRecentDate].remove('tempCredits');
      }

      await docRef.update({'dates': dates});

      _fetchMemberDetails();
      _showSnackBar('Temporary credits removed for ${user['email']}');
    } catch (e) {
      print('Error removing credits: $e');
      _showSnackBar('Failed to remove credits', isError: true);
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
      appBar: AppBar(
        title: Text('User Details'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : memberDetails.isEmpty
          ? Center(child: Text('No members found.'))
          : ListView.builder(
        itemCount: memberDetails.length,
        itemBuilder: (context, index) {
          final user = memberDetails[index];
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      child: Text(user['name']?.substring(0, 1) ?? '?'),
                    ),
                    title: Text(user['name'] ?? 'Unknown Name'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email: ${user['email']}'),
                        Text('Member ID: ${user['memberId'] ?? 'N/A'}'),
                        Text('Extra Credits: ${user['tempCredits']}'), // Display tempCredits
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () => _handleRightTick(user),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () => _handleWrongTick(user),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
