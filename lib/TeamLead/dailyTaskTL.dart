import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class AdminTaskPage extends StatefulWidget {
  const AdminTaskPage({Key? key}) : super(key: key);

  @override
  _AdminTaskPageState createState() => _AdminTaskPageState();
}

class _AdminTaskPageState extends State<AdminTaskPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime selectedDate = DateTime.now();
  final DateFormat dateFormatter = DateFormat('dd-MM-yyyy');
  Map<String, Map<String, List<Map<String, dynamic>>>> tasksByDateAndEmail = {};
  List<String> userEmails = [];

  @override
  void initState() {
    super.initState();
    _loadTasksForCalendar();
  }

  Future<void> _loadTasksForCalendar() async {
    // First, get all members to have their email IDs
    final membersSnapshot = await _firestore.collection('members').get();
    Map<String, String> memberDocs = {};

    for (var member in membersSnapshot.docs) {
      final email = member.data()['email'] as String;
      memberDocs[member.id] = email;
      if (!userEmails.contains(email)) {
        userEmails.add(email);
      }
    }

    // Now load tasks for each member
    Map<String, Map<String, List<Map<String, dynamic>>>> tempTasks = {};

    for (var memberId in memberDocs.keys) {
      final tasksSnapshot = await _firestore
          .collection('members')
          .doc(memberId)
          .collection('dailyTasks')
          .get();

      for (var doc in tasksSnapshot.docs) {
        final date = doc.id;
        final tasks = List<Map<String, dynamic>>.from(
            (doc.data() as Map<String, dynamic>)['tasks'] ?? []);

        if (tasks.isNotEmpty) {
          tempTasks[date] ??= {};
          tempTasks[date]![memberDocs[memberId]!] ??= [];
          tempTasks[date]![memberDocs[memberId]!]?.addAll(tasks);
        }
      }
    }

    setState(() {
      tasksByDateAndEmail = tempTasks;
    });
  }

  List<DateTime> _getMarkersForDate(DateTime day) {
    List<DateTime> markers = [];
    final dateStr = dateFormatter.format(day);

    if (tasksByDateAndEmail.containsKey(dateStr)) {
      markers.add(day);
    }

    return markers;
  }

  void _showUserTasksModal(BuildContext context, String email) {
    final dateStr = dateFormatter.format(selectedDate);
    final userTasks = tasksByDateAndEmail[dateStr]?[email] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          color: Colors.white,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Task header with email text, handle overflow for long emails
                  Expanded(
                    child: Text(
                      'Tasks for $email',
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        overflow: TextOverflow.ellipsis, // Handle long email overflow
                      ),
                      maxLines: 1, // Ensure the email doesn't take more than one line
                    ),
                  ),
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              // Tasks list
              Expanded(
                child: userTasks.isEmpty
                    ? const Center(
                  child: Text('No tasks for this date'),
                )
                    : ListView.builder(
                  itemCount: userTasks.length,
                  itemBuilder: (context, index) {
                    final task = userTasks[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(task['title']),
                        subtitle: Text(task['description']),
                        leading: const FaIcon(FontAwesomeIcons.tasks),
                        trailing: task['completed'] == true
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.pending_actions, color: Colors.orange),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final dateStr = dateFormatter.format(selectedDate);
    final activeUsers = tasksByDateAndEmail[dateStr]?.keys.toList() ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Admin: View All Tasks'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          TableCalendar(
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
              defaultTextStyle: TextStyle(color: Colors.black),
              // Set a white background color for the calendar days
              todayDecoration: BoxDecoration(
                color: Colors.tealAccent,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.teal,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1,
              markerDecoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),

              weekendTextStyle: TextStyle(
                color: Colors.red, // Make weekends red
              ),
            ),
            headerStyle: const HeaderStyle(
              titleTextStyle: TextStyle(color: Colors.teal), // Adjust title color
              formatButtonVisible: false,
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.teal),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.teal),
            ),
            eventLoader: (day) {
              return _getMarkersForDate(day);
            },
          ),

          const Divider(),
          Expanded(
            child: activeUsers.isEmpty
                ? const Center(
              child: Text('No tasks for this date'),
            )
                : ListView.builder(
              itemCount: activeUsers.length,
              itemBuilder: (context, index) {
                final email = activeUsers[index];
                final tasksCount =
                    tasksByDateAndEmail[dateStr]?[email]?.length ?? 0;
                return ListTile(
                  title: Text(email,style: TextStyle(color: Colors.black),),
                  subtitle: Text('$tasksCount tasks'),
                  leading: const CircleAvatar(
                    child: FaIcon(FontAwesomeIcons.user),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showUserTasksModal(context, email),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}