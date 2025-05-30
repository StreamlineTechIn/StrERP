import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class DailyTaskPage extends StatefulWidget {
  const DailyTaskPage({Key? key}) : super(key: key);

  @override
  _DailyTaskPageState createState() => _DailyTaskPageState();
}

class _DailyTaskPageState extends State<DailyTaskPage> {
  String? memberDocId;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color backgroundColor = Color(0xFFFFFFFE);  // Off white
  DateTime selectedDate = DateTime.now(); // For the calendar
  final DateFormat dateFormatter = DateFormat('dd-MM-yyyy');
  Map<DateTime, List> markedDates = {};  // To hold the dates with tasks

  // List to manage multiple tasks in the dialog
  List<Map<String, TextEditingController>> _taskControllers = [];

  @override
  void initState() {
    super.initState();
    _fetchMemberDocId();
    _fetchTaskDates();
  }

  @override
  void dispose() {
    _clearTaskControllers();
    super.dispose();
  }

  // Fetch member document ID
  Future<void> _fetchMemberDocId() async {
    final userEmail = _auth.currentUser?.email;
    if (userEmail != null) {
      try {
        final query = await _firestore
            .collection('members')
            .where('email', isEqualTo: userEmail)
            .get();

        if (!mounted) return; // Check if widget is still in the tree

        if (query.docs.isNotEmpty) {
          setState(() {
            memberDocId = query.docs.first.id;
          });
        }
      } catch (e) {
        print('Error fetching member doc ID: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  // Fetch task dates and store them in the markedDates map
  Future<void> _fetchTaskDates() async {
    if (memberDocId == null) return;

    final tasksRef = _firestore
        .collection('members')
        .doc(memberDocId)
        .collection('dailyTasks');

    final snapshot = await tasksRef.get();

    final taskDates = <DateTime>[];
    for (var doc in snapshot.docs) {
      final taskDateString = doc.id;
      final taskDate = dateFormatter.parse(taskDateString);
      taskDates.add(taskDate);
    }

    setState(() {
      markedDates = {
        for (var date in taskDates)
          date: ['task']  // You can add more details if needed
      };
    });
  }

  // Delete a specific task
  Future<void> _deleteTask(Map<String, dynamic> taskToRemove) async {
    if (memberDocId == null) return;

    try {
      final dailyTasksRef = _firestore
          .collection('members')
          .doc(memberDocId)
          .collection('dailyTasks')
          .doc(dateFormatter.format(selectedDate));

      // Remove the task from the list of tasks for the selected date
      await dailyTasksRef.update({
        'tasks': FieldValue.arrayRemove([taskToRemove]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted successfully')),
      );

      // Refresh task dates
      await _fetchTaskDates();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting task: $e')),
      );
    }
  }

  // Method to add task input fields
  void _addTaskInputFields({String? title, String? description}) {
    _taskControllers.add({
      'title': TextEditingController(text: title ?? ''),
      'description': TextEditingController(text: description ?? ''),
    });
  }

  // Method to clear task controllers
  void _clearTaskControllers() {
    for (var controller in _taskControllers) {
      controller['title']?.dispose();
      controller['description']?.dispose();
    }
    _taskControllers.clear();
  }

  // Modified method to save multiple tasks
  Future<void> _saveMultipleTasks(Map<String, dynamic>? oldTask) async {
    if (memberDocId == null) return;

    final List<Map<String, dynamic>> newTasks = _taskControllers
        .where((controller) =>
    controller['title']!.text.isNotEmpty ||
        controller['description']!.text.isNotEmpty)
        .map((controller) => {
      'title': controller['title']!.text,
      'description': controller['description']!.text,
    })
        .toList();

    if (newTasks.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final dailyTasksRef = _firestore
          .collection('members')
          .doc(memberDocId)
          .collection('dailyTasks')
          .doc(dateFormatter.format(selectedDate));

      if (oldTask != null) {
        // If editing, first remove the old task
        await dailyTasksRef.update({
          'tasks': FieldValue.arrayRemove([oldTask]),
        });
      }

      // Add the new tasks
      await dailyTasksRef.set(
        {
          'tasks': FieldValue.arrayUnion(newTasks),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      Navigator.pop(context);
      _clearTaskControllers();

      // Re-fetch task dates after adding/editing tasks
      await _fetchTaskDates();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving tasks: $e')),
      );
    }
  }

  // Delete all tasks for the selected date
  Future<void> _deleteAllTasks() async {
    if (memberDocId == null) return;

    try {
      await _firestore
          .collection('members')
          .doc(memberDocId)
          .collection('dailyTasks')
          .doc(dateFormatter.format(selectedDate))
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All tasks deleted successfully')),
      );

      // Refresh task dates
      await _fetchTaskDates();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting tasks: $e')),
      );
    }
  }

  void _showTaskDialog({Map<String, dynamic>? task}) {
    // Clear previous task controllers
    _taskControllers.clear();

    // If editing an existing task, pre-populate
    if (task != null) {
      _addTaskInputFields(
        title: task['title'],
        description: task['description'],
      );
    } else {
      // Start with one empty task input
      _addTaskInputFields();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(task == null ? 'Add Tasks' : 'Edit Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dynamically generated task input fields
                    ..._taskControllers.map((taskController) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: taskController['title'],
                                  decoration: const InputDecoration(
                                    labelText: 'Title',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    // Remove this specific task controller
                                    _taskControllers.remove(taskController);
                                  });
                                },
                              ),
                            ],
                          ),
                          TextField(
                            controller: taskController['description'],
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      );
                    }).toList(),

                    // Add Task Button
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _addTaskInputFields();
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Another Task'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context);
                    _clearTaskControllers();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () { 
                    FocusScope.of(context).unfocus();
                    _saveMultipleTasks(task);
                  },
                  child: const Text('Save'),
                ),
              ],
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
        title: const Text('Daily Tasks'),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.plusCircle),
            onPressed: () => _showTaskDialog(),
          ),
        ],
        backgroundColor: Colors.teal,
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
        child: Column(
          children: [
            // Calendar for selecting dates
            Card(
              color: Colors.white,
              child: TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime(2100),
                focusedDay: selectedDate,
                selectedDayPredicate: (day) => isSameDay(day, selectedDate),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    selectedDate = selectedDay;
                  });
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  weekendTextStyle: const TextStyle(
                    color: Colors.red, // Set weekend dates' text color to red
                  ),
                  defaultTextStyle: const TextStyle(
                    color: Colors.black, // Set remaining dates' text color to black
                  ),
                  markersMaxCount: 1,
                  markerDecoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  leftChevronIcon: Icon(Icons.chevron_left, color: Colors.teal), // Left arrow
                  rightChevronIcon: Icon(Icons.chevron_right, color: Colors.teal), // Right arrow
                  titleTextStyle: TextStyle(
                    color: Colors.teal, // Month and year text color
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                eventLoader: (day) {
                  // Return events for a specific date
                  if (markedDates.containsKey(day)) {
                    return ['task']; // Mark the date with a task
                  }
                  return []; // No task for this day
                },
              ),
            ),
            // Task list and delete all button
            Expanded(
              child: memberDocId == null
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<DocumentSnapshot>(
                stream: _firestore
                    .collection('members')
                    .doc(memberDocId)
                    .collection('dailyTasks')
                    .doc(dateFormatter.format(selectedDate))
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading tasks.'));
                  }

                  final data = snapshot.data?.data() as Map<String, dynamic>?;

                  if (data == null || data['tasks'] == null || (data['tasks'] as List).isEmpty) {
                    return const Center(child: Text('No tasks for the selected date.', style: TextStyle(color: Colors.black)));
                  }

                  final tasks = List<Map<String, dynamic>>.from(data['tasks']);

                  return Column(
                    children: [
                      // Only show the Delete All Tasks button if tasks are available
                      if (tasks.isNotEmpty)
                        ElevatedButton(
                          onPressed: _deleteAllTasks,
                          child: const Text('Delete All Tasks'),
                        ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];

                            return ListTile(
                              title: Text(task['title'] ?? 'Untitled', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              subtitle: Text(task['description'] ?? 'No description', style: TextStyle(color: Colors.black)),
                              trailing: IconButton(
                                icon: const FaIcon(FontAwesomeIcons.trash, color: Colors.white),
                                onPressed: () async {
                                  // Delete the task
                                  final taskToRemove = task;
                                  await _deleteTask(taskToRemove);
                                },
                              ),
                              onTap: () {
                                _showTaskDialog(task: task);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}