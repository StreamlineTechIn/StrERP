import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:str_erp/TeamLead/TLTaskView.dart'; // For date formatting

class TLTaskManager extends StatefulWidget {
  @override
  _TLTaskManagerState createState() => _TLTaskManagerState();
}

class _TLTaskManagerState extends State<TLTaskManager> {
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDescriptionController = TextEditingController();
  final TextEditingController _subtaskTitleController = TextEditingController();

  DateTime? _dueDate;
  DateTime? _reminderDate;
  String? _priority = 'Low';
  User? user = FirebaseAuth.instance.currentUser;

  List<Map<String, dynamic>> _subtasks = [];
  List<String> _dependencies = [];
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('TLTasks').get();
    return snapshot.docs.map((doc) => {'id': doc.id, 'email': doc.id}).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchTasks(String userId) async {
    try {
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('TLTasks').doc(userId).get();
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
      final userDoc = await FirebaseFirestore.instance.collection('TLTasks').doc(userId).get();
      final data = userDoc.data() as Map<String, dynamic>?;

      final taskNumber = (data?['tasks']?.length ?? 0) + 1;

      await FirebaseFirestore.instance.collection('TLTasks').doc(userId).update({
        'tasks': FieldValue.arrayUnion([
          {
            'taskNumber': taskNumber,
            'title': _taskTitleController.text.trim(),
            'description': _taskDescriptionController.text.trim(),
            'dueDate': _dueDate,
            'reminderDate': _reminderDate,
            'priority': _priority,
            'subtasks': _subtasks,
            'dependencies': _dependencies,
            'status': 'To Do',
            'history': [],
            'completed': false, // New field for task completion status
            'assignedBy': user?.email,
          }
        ])
      });

      _taskTitleController.clear();
      _taskDescriptionController.clear();
      setState(() {
        _successMessage = 'Task assigned successfully!';
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
  }

  Future<void> _deleteTask(String userId, Map<String, dynamic> task) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await FirebaseFirestore.instance.collection('TLTasks').doc(userId).update({
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

  Future<void> _toggleTaskCompletion(String userId, Map<String, dynamic> task) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final updatedTask = {...task, 'completed': !task['completed']};

      await FirebaseFirestore.instance.collection('TLTasks').doc(userId).update({
        'tasks': FieldValue.arrayRemove([task]),
      });

      await FirebaseFirestore.instance.collection('TLTasks').doc(userId).update({
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

  void _selectDateAndTime(BuildContext context, {required bool isDueDate}) async {
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

  void _addSubtask() {
    if (_subtaskTitleController.text.isNotEmpty) {
      setState(() {
        _subtasks.add({'title': _subtaskTitleController.text.trim(), 'status': 'To Do'});
        _subtaskTitleController.clear();
      });
    }
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
                          ElevatedButton(
                            onPressed: () => _selectDateAndTime(context, isDueDate: true),
                            child: Text(
                              _dueDate != null ? 'Due Date: ${_dateFormat.format(_dueDate!)}' : 'Select Due Date',
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _selectDateAndTime(context, isDueDate: false),
                            child: Text(
                              _reminderDate != null ? 'Reminder Date: ${_dateFormat.format(_reminderDate!)}' : 'Select Reminder Date',
                            ),
                          ),
                          SizedBox(height: 20),
                          DropdownButton<String>(
                            value: _priority,
                            dropdownColor: Colors.black,
                            onChanged: (String? newValue) {
                              setState(() {
                                _priority = newValue;
                              });
                            },
                            items: <String>['Low', 'Medium', 'High']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 20),
                          TextField(
                            controller: _subtaskTitleController,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Subtask Title',
                              labelStyle: TextStyle(color: Colors.white),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue),
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _addSubtask,
                            child: Text('Add Subtask'),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Subtasks:',
                            style: TextStyle(color: Colors.white),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            itemCount: _subtasks.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(
                                  _subtasks[index]['title'],
                                  style: TextStyle(color: Colors.white),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => _assignTask(userId, email),
                            child: Text('Assign Task'),
                          ),
                          if (_errorMessage != null) ...[
                            SizedBox(height: 20),
                            Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                          if (_successMessage != null) ...[
                            SizedBox(height: 20),
                            Text(
                              _successMessage!,
                              style: TextStyle(color: Colors.green),
                            ),
                          ],
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

  void _showTaskDetailsDialog(String userId, Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassmorphicContainer(
            width: MediaQuery.of(context).size.width * 0.85,
            height: 600,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Task #'+task['taskNumber'].toString(),
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      task['title'],
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      task['description'],
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Due Date: ${task['dueDate'] != null ? _dateFormat.format(task['dueDate'].toDate()) : 'Not set'}',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Reminder Date: ${task['reminderDate'] != null ? _dateFormat.format(task['reminderDate'].toDate()) : 'Not set'}',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Priority: ${task['priority']}',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Subtasks:',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 20,),
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: task['subtasks']?.length ?? 0,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(
                            task['subtasks'][index]['title'],
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        _toggleTaskCompletion(userId, task);
                        Navigator.of(context).pop();
                      },
                      child: Text(task['completed'] ? 'Mark as Incomplete' : 'Mark as Complete'),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        _deleteTask(userId, task);
                        Navigator.of(context).pop();
                      },
                      child: Text('Delete Task'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Task Manager',
          style: GoogleFonts.montserrat(),
        ),
        backgroundColor: Colors.transparent,

      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else {
            final users = snapshot.data!;
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchTasks(user['id']),
                  builder: (context, taskSnapshot) {
                    if (taskSnapshot.connectionState == ConnectionState.waiting) {
                      return ListTile(
                        title: Column(
                          children: [
                            Text(
                              user['email'],
                              style: GoogleFonts.montserrat(color: Colors.white),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Loading tasks...',
                          style: GoogleFonts.montserrat(color: Colors.white),
                        ),
                      );
                    } else if (taskSnapshot.hasError) {
                      return ListTile(
                        title: Text(
                          user['email'],
                          style: GoogleFonts.montserrat(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Error loading tasks',
                          style: GoogleFonts.montserrat(color: Colors.white),
                        ),
                      );
                    } else {
                      final tasks = taskSnapshot.data!;
                      return ExpansionTile(
                        title: Text(
                          user['email'],
                          style: GoogleFonts.montserrat(color: Colors.white),
                        ),
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            itemCount: tasks.length,
                            itemBuilder: (context, taskIndex) {
                              final task = tasks[taskIndex];
                              return ListTile(
                                title: Column(
                                  mainAxisAlignment: MainAxisAlignment.start ,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Task #'+task['taskNumber'].toString(),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      task['title'],
                                      style: GoogleFonts.montserrat(color: Colors.white),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  children: [
                                    Text(
                                      'Due: ${task['dueDate'] != null ? _dateFormat.format(task['dueDate'].toDate()) : 'Not set'}',
                                      style: GoogleFonts.montserrat(color: Colors.white),
                                    ),
                                    Divider()
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.info_outline, color: Colors.white),
                                  onPressed: () => _showTaskDetailsDialog(user['id'], task),
                                ),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: ElevatedButton(
                              onPressed: () => _showAssignTaskDialog(user['email'], user['id']),
                              child: Text('Assign Task to ${user['email']}'),
                            ),
                          ),
                        ],
                      );
                    }
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: TLTaskManager(),
  ));
}
