import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For date formatting

class TLAssignedTasks extends StatefulWidget {
   // User ID to fetch tasks for the specific user

  TLAssignedTasks({super.key});

  @override
  _TLAssignedTasksState createState() => _TLAssignedTasksState();
}

class _TLAssignedTasksState extends State<TLAssignedTasks> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _tasks = [];
  User? user = FirebaseAuth.instance.currentUser;
  final Color backgroundColor = Color(0xFFFFFFFE);  // Off white


  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    try {
      // Access the document where the current user email matches the document name
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('TLTasks')
          .doc(user?.email)
          .get();

      if (!userDoc.exists) {
        throw Exception('No user found with the provided email.');
      }

      final data = userDoc.data() as Map<String, dynamic>?;

      setState(() {
        _tasks = List<Map<String, dynamic>>.from(data?['tasks'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching tasks: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleTaskCompletion(Map<String, dynamic> task) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Access the document where the current user email matches the document name
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('TLTasks')
          .doc(user?.email) // Make sure widget.userId is the user's email
          .get();

      if (!userDoc.exists) {
        throw Exception('No document found with the provided email.');
      }

      final docId = userDoc.id;

      final updatedTask = {...task, 'completed': !(task['completed'] ?? false)};

      // Update the task in Firestore
      await FirebaseFirestore.instance.collection('TLTasks').doc(docId).update({
        'tasks': FieldValue.arrayRemove([task]),
      });

      await FirebaseFirestore.instance.collection('TLTasks').doc(docId).update({
        'tasks': FieldValue.arrayUnion([updatedTask]),
      });

      setState(() {
        _tasks[_tasks.indexOf(task)] = updatedTask;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }


  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(bool completed) {
    return completed ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Tasks', style: GoogleFonts.montserrat()),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(child: Text(_errorMessage!, style: GoogleFonts.montserrat(fontSize: 18, color: Colors.red)))
            : _tasks.isEmpty
            ? Center(child: Text('No tasks assigned.', style: GoogleFonts.montserrat(fontSize: 18)))
            : ListView.builder(
          itemCount: _tasks.length,
          itemBuilder: (context, index) {
            final task = _tasks[index];
            final dueDate = task['dueDate'] != null
                ? _dateFormat.format((task['dueDate'] as Timestamp).toDate())
                : 'No due date';
            final taskNumber = task['taskNumber'] ?? index + 1;
            final completed = task['completed'] ?? false;
            final subTasks = task['subTasks'] ?? [];

            return Card(
              elevation: 5,
              margin: EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
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

                child: ExpansionTile(
                  title: Text(
                    'Task #$taskNumber\n${task['title'] ?? 'No Title'}',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8),
                      Text(
                        task['description'] ?? 'No Description',
                        style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white70),
                      ),
                      SizedBox(height: 15),
                      Row(
                        children: [
                          Icon(Icons.date_range, color: Colors.white),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Due Date: $dueDate',
                              style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star, color: _getPriorityColor(task['priority'] ?? 'Low')),
                          SizedBox(width: 10),
                          Text(
                            'Priority: ${task['priority'] ?? 'Low'}',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: _getPriorityColor(task['priority'] ?? 'Low'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.flag, color: _getStatusColor(completed)),
                          SizedBox(width: 10),
                          Text(
                            'Status: ${completed ? 'Completed' : 'Pending'}',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: _getStatusColor(completed),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.assignment, color: Colors.white),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Assigned By:\n ${task['assignedBy'] ?? 'Unknown'}',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  children: [
                    ...subTasks.map<Widget>((subTask) {
                      return ListTile(
                        title: Text(
                          subTask['title'] ?? 'No Title',
                          style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white),
                        ),
                        subtitle: Text(
                          subTask['description'] ?? 'No Description',
                          style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white70),
                        ),
                      );
                    }).toList(),
                    TextButton(
                      onPressed: () => _toggleTaskCompletion(task),
                      child: Text(
                        completed ? 'Mark as Pending' : 'Mark as Completed',
                        style: GoogleFonts.montserrat(
                          color: completed ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
