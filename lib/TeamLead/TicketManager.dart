import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminTicketPage extends StatefulWidget {
  @override
  _AdminTicketPageState createState() => _AdminTicketPageState();
}

class _AdminTicketPageState extends State<AdminTicketPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _tickets = [];
  User? user = FirebaseAuth.instance.currentUser;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _dateFormat = DateFormat('MMMM d, yyyy \u{2022} h:mm:ss a');

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    try {
      final QuerySnapshot ticketSnapshot = await FirebaseFirestore.instance
          .collection('tickets')
          .get();

      setState(() {
        _tickets = ticketSnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>
        }).toList();

        _tickets.sort((a, b) {
          DateTime dateA = (a['createdAt'] as Timestamp).toDate();
          DateTime dateB = (b['createdAt'] as Timestamp).toDate();
          return dateB.compareTo(dateA);
        });

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching tickets: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTicketStatus(String ticketId, String status) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Update status and timestamp
      Map<String, dynamic> data = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(), // This sets the timestamp on the server
        'updatedBy':user?.email,
      };

      if (status == 'In Progress') {
        data['inProgressAt'] = FieldValue.serverTimestamp();
      } else if (status == 'Resolved') {
        data['resolvedAt'] = FieldValue.serverTimestamp();
      } else if (status == 'Pending') {
        data['inProgressAt'] = null;
        data['resolvedAt'] = null;
      }

      await FirebaseFirestore.instance.collection('tickets').doc(ticketId).update(data);
      await _fetchTickets(); // Refresh tickets after update
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating ticket status: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTicket(String ticketId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('tickets').doc(ticketId).delete();
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
        title: Text('Manage Tickets', style: GoogleFonts.montserrat()),
        backgroundColor: Colors.teal,
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
            children: [
              if (_errorMessage != null)
                Text(_errorMessage!, style: TextStyle(color: Colors.red)),
              Expanded(
                child: ListView.builder(
                  itemCount: _tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = _tickets[index];
                    final createdAt = (ticket['createdAt'] as Timestamp).toDate();
                    final category = ticket['category'] ?? 'Unknown';
                    final description = ticket['description'] ?? 'No Description';
                    final priority = ticket['priority'] ?? 'Low';
                    final raisedBy = ticket['raisedBy'] ?? 'Unknown';
                    final status = ticket['status'] ?? 'Pending';
                    final title = ticket['title'] ?? 'No Title';
                    final updatedAt = (ticket['updatedAt'] as Timestamp).toDate();//last change

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: LinearGradient(
                            colors: [Colors.white, Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          title: Row(
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.montserrat(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(priority),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  priority,
                                  style: GoogleFonts.montserrat(color: Colors.black),
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) => _updateTicketStatus(ticket['id'], value),
                                itemBuilder: (context) => [
                                  PopupMenuItem(value: 'Pending', child: Text('Pending')),
                                  PopupMenuItem(value: 'In Progress', child: Text('In Progress')),
                                  PopupMenuItem(value: 'Resolved', child: Text('Resolved')),
                                ],
                                icon: Icon(Icons.more_vert, color: Colors.black),
                              )
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 8),
                              Text(
                                'Category: $category',
                                style: GoogleFonts.montserrat(color: Colors.black),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Raised By: $raisedBy',
                                style: GoogleFonts.montserrat(color: Colors.black),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Created At: ${_dateFormat.format(createdAt)}',
                                style: GoogleFonts.montserrat(color: Colors.black),
                              ),
                              SizedBox(height: 4),
                              if (ticket['inProgressAt'] != null) Text(
                                'Resolving At: ${_dateFormat.format(ticket['inProgressAt'].toDate())}',
                                style: GoogleFonts.montserrat(color: Colors.black),
                              ),
                              SizedBox(height: 4),
                              if (ticket['resolvedAt'] != null) Text(
                                'Resolved At: ${_dateFormat.format(ticket['resolvedAt'].toDate())}',
                                style: GoogleFonts.montserrat(color: Colors.black),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Description: $description',
                                style: GoogleFonts.montserrat(color: Colors.black),
                              ),


                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status,
                                      style: GoogleFonts.montserrat(color: Colors.black),
                                    ),
                                  ),
                                  Spacer(),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.black),
                                    onPressed: () => _deleteTicket(ticket['id']),
                                  ),

                                ],
                              ),

                              Text(
                                'Updated At:\n ${DateFormat('yyyy-MM-dd – kk:mm').format(updatedAt)}',
                                style: GoogleFonts.montserrat(color: Colors.black),
                              ),
                              Text(
                                'By: ${ticket['updatedBy']}',
                                style: GoogleFonts.montserrat(color: Colors.black),
                                softWrap: true,
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
    );
  }
}