import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../TeamLead/taskManager.dart'; // For date formatting

class AssignedTasksPage extends StatefulWidget {
  final String? userId; // User ID to fetch tasks for the specific user

  AssignedTasksPage({required this.userId});

  @override
  _AssignedTasksPageState createState() => _AssignedTasksPageState();
}

class _AssignedTasksPageState extends State<AssignedTasksPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _tasks = [];

  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final Color backgroundColor = Color(0xFFFFFFFE);  // Off white

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    try {
      final QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: widget.userId) // Ensure widget.userId is provided
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception('No user found with the provided email.');
      }

      final DocumentSnapshot userDoc = userSnapshot.docs.first;
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
      final QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: widget.userId)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception('No user found with the provided email.');
      }

      final DocumentSnapshot userDoc = userSnapshot.docs.first;
      final docId = userDoc.id;

      final updatedTask = {...task, 'completed': !(task['completed'] ?? false)};

      await FirebaseFirestore.instance.collection('members').doc(docId).update({
        'tasks': FieldValue.arrayRemove([task]),
      });

      await FirebaseFirestore.instance.collection('members').doc(docId).update({
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

  Future<void> _toggleSubtaskCompletion(Map<String, dynamic> task, int subtaskIndex) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch the user document
      final QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: widget.userId)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception('No user found with the provided email.');
      }

      final DocumentSnapshot userDoc = userSnapshot.docs.first;
      final docId = userDoc.id;

      // Toggle subtask completion
      final subtask = task['subtasks'][subtaskIndex];
      final updatedSubtask = {
        ...subtask,
        'completed': !(subtask['completed'] ?? false),
        'completionDate': Timestamp.now(),
      };

      // Update subtasks
      final updatedTask = {
        ...task,
        'subtasks': [
          ...task['subtasks'].sublist(0, subtaskIndex),
          updatedSubtask,
          ...task['subtasks'].sublist(subtaskIndex + 1),
        ]
      };

      // Check if all subtasks are completed
      final allSubtasksCompleted = updatedTask['subtasks'].every((subtask) => subtask['completed'] == true);
      final newCompletionStatus = allSubtasksCompleted;

      // Update the main task's completion status if needed
      if (task['completed'] != newCompletionStatus) {
        updatedTask['completed'] = newCompletionStatus;
      }

      // Update Firestore
      await FirebaseFirestore.instance.collection('members').doc(docId).update({
        'tasks': FieldValue.arrayRemove([task]),
      });

      await FirebaseFirestore.instance.collection('members').doc(docId).update({
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
        title: Text('My Tasks', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(onPressed: (){Navigator.push(context, MaterialPageRoute(builder: (context)=>TaskManagerPage()));}, icon: Icon( Icons.access_time))

        ],
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
            final subTasks = task['subtasks'] ?? []; // Ensure 'subtasks' is used

            return Card(
              elevation: 5,
              margin: EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.tealAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ExpansionTile(
                  title: Text(
                    'Task #$taskNumber\n${task['title'] ?? 'No Title'}',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8),
                      Text(
                        task['description'] ?? 'No Description',
                        style: GoogleFonts.montserrat(fontSize: 14, color: Colors.black54),
                      ),
                      SizedBox(height: 15),
                      Row(
                        children: [
                          Icon(Icons.date_range, color: Colors.black),
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
                          Icon(Icons.assignment, color: Colors.black),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Assigned By:\n${task['assignedBy'] ?? 'Unknown'}',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: Colors.black,
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
                      final subtaskCompleted = subTask['completed'] ?? false;
                      final subtaskCompletionDate = subTask['completionDate'] != null
                          ? _dateFormat.format((subTask['completionDate'] as Timestamp).toDate())
                          : 'Not Completed';

                      return ListTile(
                        leading: IconButton(
                          icon: Icon(
                            subtaskCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                            color: subtaskCompleted ? Colors.green : Colors.grey,
                          ),
                          onPressed: () => _toggleSubtaskCompletion(task, subTasks.indexOf(subTask)),
                        ),
                        title: Text(
                          subTask['title'] ?? 'No Title',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: subtaskCompleted ? Colors.green : Colors.white,
                            decoration: subtaskCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                          ),
                        ),
                        subtitle: Text(
                          subtaskCompletionDate,
                          style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white70),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
        ),
    );
  }
}
