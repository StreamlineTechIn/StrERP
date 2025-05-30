import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For date formatting

class TaskManagerPage extends StatefulWidget {
  @override
  _TaskManagerPageState createState() => _TaskManagerPageState();
}

class _TaskManagerPageState extends State<TaskManagerPage> {
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDescriptionController =
      TextEditingController();
  final TextEditingController _subtaskTitleController = TextEditingController();

  DateTime? _dueDate;
  DateTime? _reminderDate;
  String? _priority = 'Low';
  User? user = FirebaseAuth.instance.currentUser;

  List<Map<String, dynamic>> _subtasks = [];
  List<String> _dependencies = [];
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return []; // Handle case where no user is signed in
    }

    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('members')
        .where('TL', isEqualTo: currentUser.email) // Filter by TL field
        .get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, 'email': doc['email']})
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchTasks(String userId) async {
    try {
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('members')
          .doc(userId)
          .get();
      final data = userDoc.data() as Map<String, dynamic>?;

      final tasks = List<Map<String, dynamic>>.from(data?['tasks'] ?? []);
      return tasks;
    } catch (e) {
      print('Error fetching tasks: $e');
      return [];
    }
  }

  Future<void> _assignTask(String userId, String email) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Validate required fields
      if (_taskTitleController.text.trim().isEmpty) {
        throw 'Task title is required';
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('members')
          .doc(userId)
          .get();
      final data = userDoc.data() as Map<String, dynamic>?;

      final taskNumber = (data?['tasks']?.length ?? 0) + 1;

      // Convert DateTime to Timestamp for Firestore
      final dueDateTimestamp = _dueDate != null ? Timestamp.fromDate(_dueDate!) : null;
      final reminderDateTimestamp = _reminderDate != null ? Timestamp.fromDate(_reminderDate!) : null;

      final newTask = {
        'taskNumber': taskNumber,
        'title': _taskTitleController.text.trim(),
        'description': _taskDescriptionController.text.trim(),
        'dueDate': dueDateTimestamp,
        'reminderDate': reminderDateTimestamp,
        'priority': _priority,
        'subtasks': _subtasks.map((subtask) => {
          ...subtask,
          'completed': false,
        }).toList(),
        'dependencies': _dependencies,
        'status': 'To Do',
        'history': [],
        'completed': false,
        'assignedBy': user?.email,
        'assignedAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('members')
          .doc(userId)
          .update({
        'tasks': FieldValue.arrayUnion([newTask])
      });

      // Clear form
      _taskTitleController.clear();
      _taskDescriptionController.clear();
      _subtaskTitleController.clear();
      setState(() {
        _subtasks = [];
        _dependencies = [];
        _dueDate = null;
        _reminderDate = null;
        _priority = 'Low';
        _successMessage = 'Task assigned successfully!';
      });

      // Close dialog after successful assignment
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
  }

  Future<void> _deleteTask(String userId, Map<String, dynamic> task) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('members')
          .doc(userId)
          .update({
        'tasks': FieldValue.arrayRemove([task])
      });

      setState(() {
        _successMessage = 'Task deleted successfully!';
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
  }

  Future<void> _toggleTaskCompletion(
      String userId, Map<String, dynamic> task) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final updatedTask = {...task, 'completed': !task['completed']};

      await FirebaseFirestore.instance
          .collection('members')
          .doc(userId)
          .update({
        'tasks': FieldValue.arrayRemove([task]),
      });

      await FirebaseFirestore.instance
          .collection('members')
          .doc(userId)
          .update({
        'tasks': FieldValue.arrayUnion([updatedTask]),
      });

      setState(() {
        _successMessage = 'Task updated successfully!';
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
  }

  void _selectDateAndTime(BuildContext context,
      {required bool isDueDate}) async {
    DateTime now = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now),
      );

      if (pickedTime != null) {
        setState(() {
          DateTime combinedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isDueDate) {
            _dueDate = combinedDateTime;
          } else {
            _reminderDate = combinedDateTime;
          }
        });
      }
    }
  }

  void _addSubtask(StateSetter updateState) {
    if (_subtaskTitleController.text.isNotEmpty) {
      updateState(() {
        _subtasks.add(
            {'title': _subtaskTitleController.text.trim(), 'status': 'To Do'});
        _subtaskTitleController.clear();
      });
    }
  }

  void _removeSubtask(int index, StateSetter updateState) {
    updateState(() {
      _subtasks.removeAt(index);
    });
  }

  void _showAssignTaskDialog(String email, String userId) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: GlassmorphicContainer(
                width: MediaQuery.of(context).size.width * 0.85,
                height: _isLoading ? 400 : 500,
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
                          'Assign Task to $email',
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
                            'Assigning task...',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ] else ...[
                          TextField(
                            controller: _taskTitleController,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Task Title',
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
                            controller: _taskDescriptionController,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Task Description',
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
                          Column(
                            children: [
                              Text(
                                  'Due Date:\n ${_dueDate != null ? _dateFormat.format(_dueDate!) : 'Not Set'}',
                                  style: TextStyle(color: Colors.white)),
                              ElevatedButton(
                                onPressed: () => _selectDateAndTime(context,
                                    isDueDate: true),
                                child: Text('Select Due Date'),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Column(
                            children: [
                              Text(
                                  'Reminder Date:\n ${_reminderDate != null ? _dateFormat.format(_reminderDate!) : 'Not Set'}',
                                  style: TextStyle(color: Colors.white)),
                              ElevatedButton(
                                onPressed: () => _selectDateAndTime(context,
                                    isDueDate: false),
                                child: Text('Select Reminder Date'),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          DropdownButton<String>(
                            value: _priority,
                            dropdownColor: Colors.blueGrey,
                            items: ['Low', 'Medium', 'High'].map((priority) {
                              return DropdownMenuItem(
                                value: priority,
                                child: Text(priority,
                                    style: TextStyle(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _priority = value;
                              });
                            },
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Subtasks:',
                            style: GoogleFonts.montserrat(
                                fontSize: 16, color: Colors.white),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            itemCount: _subtasks.length,
                            itemBuilder: (context, index) {
                              final subtask = _subtasks[index];
                              return ListTile(
                                title: Text(subtask['title'],
                                    style: TextStyle(color: Colors.white)),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () =>
                                      _removeSubtask(index, setState),
                                ),
                              );
                            },
                          ),
                          TextField(
                            controller: _subtaskTitleController,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'New Subtask Title',
                              labelStyle: TextStyle(color: Colors.white),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue),
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _addSubtask(setState),
                            child: Text('Add Subtask'),
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => _assignTask(userId, email),
                            child: Text('Assign Task'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text('Task Manager'),
        backgroundColor: Colors.teal,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal,
              Colors.white,
            ],
          ),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchUsers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final users = snapshot.data ?? [];

            if (users.isEmpty) {
              return Center(child: Text('No team members found'));
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return Card(
                        color: Colors.white,
                        margin: EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            // User header with Assign Task button
                            ListTile(
                              title: Text(
                                user['email'] ?? 'Unknown User',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black
                                ),
                              ),
                              trailing: ElevatedButton.icon(
                                icon: Icon(Icons.add_task),
                                label: Text('Assign Task'),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white, backgroundColor: Colors.teal,
                                ),
                                onPressed: () => _showAssignTaskDialog(
                                  user['email'],
                                  user['id'],
                                ),
                              ),
                            ),
                            // Tasks list
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: _fetchTasks(user['id']),
                              builder: (context, taskSnapshot) {
                                if (taskSnapshot.connectionState == ConnectionState.waiting) {
                                  return Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }

                                if (taskSnapshot.hasError) {
                                  return ListTile(
                                    title: Text('Error loading tasks: ${taskSnapshot.error}'),
                                  );
                                }

                                final tasks = taskSnapshot.data ?? [];
                                final completedTasks = tasks.where((task) => task['completed'] == true).toList();
                                final pendingTasks = tasks.where((task) => task['completed'] != true).toList();

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (pendingTasks.isNotEmpty) ...[
                                      Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text(
                                          'Pending Tasks',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                      ...pendingTasks.map((task) => _buildTaskTile(task, user['id'], false)),
                                    ],
                                    if (completedTasks.isNotEmpty) ...[
                                      Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text(
                                          'Completed Tasks',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                      ...completedTasks.map((task) => _buildTaskTile(task, user['id'], true)),
                                    ],
                                    if (tasks.isEmpty)
                                      Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text('No tasks assigned'),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task, String userId, bool isCompleted) {
    return ExpansionTile(
      title: Text(
        'Task #${task['taskNumber']} - ${task['title']}',
        style: TextStyle(
          decoration: isCompleted ? TextDecoration.lineThrough : null,
          color: isCompleted ? Colors.grey : Colors.black,
        ),
      ),
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task['description'] ?? 'No description',style: TextStyle(color: Colors.black),),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _toggleTaskCompletion(userId, task),
                child: Text(isCompleted ? 'Mark as Pending' : 'Mark as Completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCompleted ? Colors.orange : Colors.green,
                ),
              ),
              if ((task['subtasks'] ?? []).isNotEmpty) ...[
                SizedBox(height: 10),
                Text('Subtasks:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...((task['subtasks'] as List<dynamic>).map((subtask) {
                  return ListTile(
                    leading: Icon(
                      subtask['completed'] ?? false
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: subtask['completed'] ?? false ? Colors.green : Colors.grey,
                    ),
                    title: Text(
                      subtask['title'] ?? 'No Title',
                      style: TextStyle(
                        color: subtask['completed'] ?? false ? Colors.green : Colors.white,
                        decoration: subtask['completed'] ?? false
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  );
                }).toList()),
              ],
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _deleteTask(userId, task),
                child: Text('Delete Task'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
