import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class viewTLTickets extends StatefulWidget {
  @override
  _viewTLTicketsState createState() => _viewTLTicketsState();
}

class _viewTLTicketsState extends State<viewTLTickets> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _tickets = [];

  final _dateFormat = DateFormat('MMMM d, yyyy \u{2022} h:mm:ss a');

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    try {
      final QuerySnapshot ticketSnapshot = await FirebaseFirestore.instance
          .collection('TLtickets')
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

  Future<void> _updateTicketStatus(String ticketId, String status) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('TLtickets').doc(ticketId).update({
        'status': status,
      });
      await _fetchTickets();
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
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: Padding(
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
                          colors: [Colors.deepPurple, Colors.purpleAccent],
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
                                color: Colors.white,
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
                                style: GoogleFonts.montserrat(color: Colors.white),
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) => _updateTicketStatus(ticket['id'], value),
                              itemBuilder: (context) => [
                                PopupMenuItem(value: 'Pending', child: Text('Pending')),
                                PopupMenuItem(value: 'In Progress', child: Text('In Progress')),
                                PopupMenuItem(value: 'Resolved', child: Text('Resolved')),
                              ],
                              icon: Icon(Icons.more_vert, color: Colors.white),
                            )
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 8),
                            Text(
                              'Category: $category',
                              style: GoogleFonts.montserrat(color: Colors.white70),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Raised By: $raisedBy',
                              style: GoogleFonts.montserrat(color: Colors.white70),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Created At: ${_dateFormat.format(createdAt)}',
                              style: GoogleFonts.montserrat(color: Colors.white70),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Description: $description',
                              style: GoogleFonts.montserrat(color: Colors.white70),
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
                                    style: GoogleFonts.montserrat(color: Colors.white),
                                  ),
                                ),
                                Spacer(),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.white),
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
    );
  }
}
