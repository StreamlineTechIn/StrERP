import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:str_erp/TeamLead/TicketManager.dart';

class TLRaiseTicket extends StatefulWidget {
  final String? userEmail;

  TLRaiseTicket({required this.userEmail});

  @override
  _TLRaiseTicketState createState() => _TLRaiseTicketState();
}

class _TLRaiseTicketState extends State<TLRaiseTicket> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Color backgroundColor = Color(0xFFFFFFFE);  // Off white
  String _priority = 'Low';
  String _category = 'General';

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    try {
      final QuerySnapshot ticketSnapshot = await FirebaseFirestore.instance
          .collection('TLtickets')
          .where('raisedBy', isEqualTo: widget.userEmail)
          .get();

      setState(() {
        _tickets = ticketSnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching tickets: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _raiseTicket() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        await FirebaseFirestore.instance.collection('TLtickets').add({
          'title': _titleController.text,
          'description': _descriptionController.text,
          'priority': _priority,
          'category': _category,
          'raisedBy': widget.userEmail,
          'createdAt': Timestamp.now(),
          'status': 'Pending',
        });

        _titleController.clear();
        _descriptionController.clear();
        _priority = 'Low';
        _category = 'General';
        await _fetchTickets();
      } catch (e) {
        setState(() {
          _errorMessage = 'Error raising ticket: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteTicket(String ticketId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('TLtickets').doc(ticketId).delete();
      await _fetchTickets();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error deleting ticket: $e';
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
      default:
        return Colors.green;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Resolved':
      case 'Closed':
        return Colors.green;
      case 'In Progress':
        return Colors.orange;
      case 'Pending':
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Raise a Ticket', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
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
      child: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_errorMessage != null)
                Text(_errorMessage!, style: TextStyle(color: Colors.red)),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: GoogleFonts.montserrat(
                          color: Colors.black,
                          /*fontWeight: FontWeight.bold,*/),
                        fillColor: Colors.white, // Set fill color to white
                        filled: true, // Enable the fill color

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: GoogleFonts.montserrat(
                          color: Colors.black,
                         /* fontWeight: FontWeight.bold,*/),
                        fillColor: Colors.white, // Set fill color to white
                        filled: true, // Enable the fill color

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        labelStyle: GoogleFonts.montserrat(
                          color: Colors.black,
                          /*fontWeight: FontWeight.bold,*/),
                        fillColor: Colors.white, // Set fill color to white
                        filled: true, // Enable the fill color

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      items: ['Low', 'Medium', 'High'].map((priority) {
                        return DropdownMenuItem(
                          value: priority,
                          child: Text(priority),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _priority = value!;
                        });
                      },
                      dropdownColor: Colors.white,
                      style: TextStyle(color: Colors.black),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: InputDecoration(
                        labelText: 'Category',labelStyle: GoogleFonts.montserrat(
                        color: Colors.black,
                        /*fontWeight: FontWeight.bold,*/),

                        fillColor: Colors.white, // Set fill color to white
                        filled: true, // Enable the fill color

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      items: ['General', 'IT', 'HR', 'Facilities'].map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _category = value!;
                        });
                      },
                      dropdownColor: Colors.white,
                      style: TextStyle(color: Colors.black),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _raiseTicket,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade700,
                      ),
                      child: Text('Raise Ticket', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold,
                          color: Colors.white)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Raised Tickets',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white
                ),
              ),
              SizedBox(height: 16),
              Container(
                height: MediaQuery.of(context).size.height * 0.5,
                child: ListView.builder(
                  itemCount: _tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = _tickets[index];
                    final createdAt = (ticket['createdAt'] as Timestamp).toDate();

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          title: Row(
                            children: [
                              Text(
                                ticket['title'],
                                style: GoogleFonts.montserrat(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(ticket['priority']),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  ticket['priority'],
                                  style: GoogleFonts.montserrat(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 8),
                              Text(
                                'Raised on ${DateFormat('yyyy-MM-dd – kk:mm').format(createdAt)}',
                                style: GoogleFonts.montserrat(color: Colors.black),
                              ),
                              SizedBox(height: 8),
                              Text(
                                ticket['description'],
                                style: GoogleFonts.montserrat(color: Colors.black54),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(ticket['status']),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      ticket['status'],
                                      style: GoogleFonts.montserrat(color: Colors.white),
                                    ),
                                  ),
                                  Spacer(),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.black),
                                    onPressed: () => _deleteTicket(ticket['id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
