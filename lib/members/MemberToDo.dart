import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class MembersTaskList extends StatefulWidget {
  MembersTaskList({super.key});

  @override
  _MembersTaskListState createState() => _MembersTaskListState();
}

class _MembersTaskListState extends State<MembersTaskList> {
  final _formKey = GlobalKey<FormState>();
  String _taskTitle = '';
  String _taskDescription = '';
  bool _taskCompleted = false;
  User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  List<DocumentSnapshot> _tasks = [];
  final Color backgroundColor = Color(0xFFFFFFFE); // Off white

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    try {
      final QuerySnapshot taskSnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: user?.email)
          .get();

      if (taskSnapshot.docs.isNotEmpty) {
        final memberDocId = taskSnapshot.docs.first.id;

        final QuerySnapshot tasksSnapshot = await FirebaseFirestore.instance
            .collection('members')
            .doc(memberDocId)
            .collection('TODO')
            .get();

        setState(() {
          _tasks = tasksSnapshot.docs;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'No member found with the provided email.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching tasks: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addTask() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        final memberDoc = await FirebaseFirestore.instance
            .collection('members')
            .where('email', isEqualTo: user?.email)
            .get();

        if (memberDoc.docs.isNotEmpty) {
          final memberDocId = memberDoc.docs.first.id;

          await FirebaseFirestore.instance
              .collection('members')
              .doc(memberDocId)
              .collection('TODO')
              .add({
            'title': _taskTitle,
            'description': _taskDescription,
            'completed': _taskCompleted,
            'subTasks': [], // Initialize with an empty list
          });

          Navigator.pop(context); // Close the add task dialog
          _fetchTasks(); // Refresh the task list
        } else {
          setState(() {
            _errorMessage = 'No member found with the provided email.';
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error adding task: $e';
        });
      }
    }
  }

  Future<void> _toggleTaskCompletion(DocumentSnapshot task) async {
    final taskData = task.data() as Map<String, dynamic>;
    final updatedTask = {
      ...taskData,
      'completed': !(taskData['completed'] ?? false)
    };

    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: user?.email)
          .get();

      if (memberDoc.docs.isNotEmpty) {
        final memberDocId = memberDoc.docs.first.id;

        await FirebaseFirestore.instance
            .collection('members')
            .doc(memberDocId)
            .collection('TODO')
            .doc(task.id)
            .update(updatedTask);

        _fetchTasks(); // Refresh the task list
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating task: $e';
      });
    }
  }

  Future<void> _deleteTask(DocumentSnapshot task) async {
    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: user?.email)
          .get();

      if (memberDoc.docs.isNotEmpty) {
        final memberDocId = memberDoc.docs.first.id;

        await FirebaseFirestore.instance
            .collection('members')
            .doc(memberDocId)
            .collection('TODO')
            .doc(task.id)
            .delete();

        _fetchTasks(); // Refresh the task list
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error deleting task: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Member To-Do List', style: GoogleFonts.montserrat()),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Add New Task'),
                  content: StatefulBuilder(builder: (context, setState) {
                    return Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            decoration: InputDecoration(labelText: 'Title'),
                            validator: (value) =>
                                value!.isEmpty ? 'Please enter a title' : null,
                            onSaved: (value) => _taskTitle = value!,
                          ),
                          TextFormField(
                            decoration:
                                InputDecoration(labelText: 'Description'),
                            onSaved: (value) => _taskDescription = value!,
                          ),
                          SwitchListTile(
                            title: Text('Completed'),
                            value: _taskCompleted,
                            onChanged: (value) =>
                                setState(() => _taskCompleted = value),
                          ),
                        ],
                      ),
                    );
                  }),
                  actions: [
                    TextButton(
                      child: Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      child: Text('Add'),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _addTask();
                          _formKey.currentState!.save();
                        }
                      }
                    ),
                  ],
                ),
              );
            },
          ),
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
                  ? Center(
                      child: Text(_errorMessage!,
                          style: GoogleFonts.montserrat(
                              fontSize: 18, color: Colors.red)))
                  : _tasks.isEmpty
                      ? Center(
                          child: Text('No tasks found.',
                              style: GoogleFonts.montserrat(
                                  color: Colors.white, fontSize: 18)))
                      : ListView.builder(
                          itemCount: _tasks.length,
                          itemBuilder: (context, index) {
                            final task = _tasks[index];
                            final taskData =
                                task.data() as Map<String, dynamic>;
                            final completed = taskData['completed'] ?? false;

                            return Card(
                              elevation: 5,
                              margin: EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ListTile(
                                title: Text(
                                  taskData['title'] ?? 'No Title',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  taskData['description'] ?? 'No Description',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 14, color: Colors.grey),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(completed
                                          ? Icons.check_circle
                                          : Icons.check_circle_outline),
                                      color: completed
                                          ? Colors.green
                                          : Colors.grey,
                                      onPressed: () =>
                                          _toggleTaskCompletion(task),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete),
                                      color: Colors.red,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('Delete Task'),
                                            content: Text(
                                                'Are you sure you want to delete this task?'),
                                            actions: [
                                              TextButton(
                                                child: Text('Cancel'),
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                              ),
                                              TextButton(
                                                child: Text('Delete'),
                                                onPressed: () {
                                                  _deleteTask(task);
                                                  Navigator.pop(
                                                      context); // Close the delete confirmation dialog
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          TaskDetailPage(taskId: task.id),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}

class TaskDetailPage extends StatefulWidget {
  final String taskId;

  TaskDetailPage({required this.taskId, super.key});

  @override
  _TaskDetailPageState createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _formKey = GlobalKey<FormState>();
  String _subTaskTitle = '';
  String _subTaskDescription = '';
  User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  List<DocumentSnapshot> _subTasks = [];

  @override
  void initState() {
    super.initState();
    _fetchSubTasks();
  }

  Future<void> _fetchSubTasks() async {
    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: user?.email)
          .get();

      if (memberDoc.docs.isNotEmpty) {
        final memberDocId = memberDoc.docs.first.id;

        final QuerySnapshot subTasksSnapshot = await FirebaseFirestore.instance
            .collection('members')
            .doc(memberDocId)
            .collection('TODO')
            .doc(widget.taskId)
            .collection('subTasks')
            .get();

        setState(() {
          _subTasks = subTasksSnapshot.docs;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'No member found with the provided email.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching sub-tasks: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addSubTask() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        final memberDoc = await FirebaseFirestore.instance
            .collection('members')
            .where('email', isEqualTo: user?.email)
            .get();

        if (memberDoc.docs.isNotEmpty) {
          final memberDocId = memberDoc.docs.first.id;

          await FirebaseFirestore.instance
              .collection('members')
              .doc(memberDocId)
              .collection('TODO')
              .doc(widget.taskId)
              .collection('subTasks')
              .add({
            'title': _subTaskTitle,
            'description': _subTaskDescription,
            'completed': false,
          });

          Navigator.pop(context); // Close the add sub-task dialog
          _fetchSubTasks(); // Refresh the sub-task list
        } else {
          setState(() {
            _errorMessage = 'No member found with the provided email.';
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error adding sub-task: $e';
        });
      }
    }
  }

  Future<void> _toggleSubTaskCompletion(DocumentSnapshot subTask) async {
    final subTaskData = subTask.data() as Map<String, dynamic>;
    final updatedSubTask = {
      ...subTaskData,
      'completed': !(subTaskData['completed'] ?? false)
    };

    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: user?.email)
          .get();

      if (memberDoc.docs.isNotEmpty) {
        final memberDocId = memberDoc.docs.first.id;

        await FirebaseFirestore.instance
            .collection('members')
            .doc(memberDocId)
            .collection('TODO')
            .doc(widget.taskId)
            .collection('subTasks')
            .doc(subTask.id)
            .update(updatedSubTask);

        _fetchSubTasks(); // Refresh the sub-task list
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating sub-task: $e';
      });
    }
  }

  Future<void> _deleteSubTask(DocumentSnapshot subTask) async {
    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: user?.email)
          .get();

      if (memberDoc.docs.isNotEmpty) {
        final memberDocId = memberDoc.docs.first.id;

        await FirebaseFirestore.instance
            .collection('members')
            .doc(memberDocId)
            .collection('TODO')
            .doc(widget.taskId)
            .collection('subTasks')
            .doc(subTask.id)
            .delete();

        _fetchSubTasks(); // Refresh the sub-task list
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error deleting sub-task: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task Details', style: GoogleFonts.montserrat()),
        backgroundColor: Colors.deepPurple.shade700,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Add New Sub-Task'),
                  content: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          decoration: InputDecoration(labelText: 'Title'),
                          validator: (value) =>
                              value!.isEmpty ? 'Please enter a title' : null,
                          onSaved: (value) => _subTaskTitle = value!,
                        ),
                        TextFormField(
                          decoration: InputDecoration(labelText: 'Description'),
                          onSaved: (value) => _subTaskDescription = value!,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      child: Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      child: Text('Add'),
                      onPressed: _addSubTask,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Text(_errorMessage!,
                        style: GoogleFonts.montserrat(
                            fontSize: 18, color: Colors.red)))
                : _subTasks.isEmpty
                    ? Center(
                        child: Text('No sub-tasks found.',
                            style: GoogleFonts.montserrat(fontSize: 18)))
                    : ListView.builder(
                        itemCount: _subTasks.length,
                        itemBuilder: (context, index) {
                          final subTask = _subTasks[index];
                          final subTaskData =
                              subTask.data() as Map<String, dynamic>;
                          final completed = subTaskData['completed'] ?? false;

                          return Card(
                            elevation: 5,
                            margin: EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              title: Text(
                                subTaskData['title'] ?? 'No Title',
                                style: GoogleFonts.montserrat(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                subTaskData['description'] ?? 'No Description',
                                style: GoogleFonts.montserrat(
                                    fontSize: 14, color: Colors.grey),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(completed
                                        ? Icons.check_circle
                                        : Icons.check_circle_outline),
                                    color:
                                        completed ? Colors.green : Colors.grey,
                                    onPressed: () =>
                                        _toggleSubTaskCompletion(subTask),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete),
                                    color: Colors.red,
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('Delete Sub-Task'),
                                          content: Text(
                                              'Are you sure you want to delete this sub-task?'),
                                          actions: [
                                            TextButton(
                                              child: Text('Cancel'),
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                            ),
                                            TextButton(
                                              child: Text('Delete'),
                                              onPressed: () {
                                                _deleteSubTask(subTask);
                                                Navigator.pop(
                                                    context); // Close the delete confirmation dialog
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    },
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
