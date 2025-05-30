import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:str_erp/TeamLead/TicketManager.dart';

class RaiseTicketPage extends StatefulWidget {
  final String? userEmail;

  RaiseTicketPage({required this.userEmail});

  @override
  _RaiseTicketPageState createState() => _RaiseTicketPageState();
}

class _RaiseTicketPageState extends State<RaiseTicketPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _priority = 'Low';
  String _category = 'General';
  final Color backgroundColor = Color(0xFFFFFFFE);  // Off white


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
          .collection('tickets')
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
        await FirebaseFirestore.instance.collection('tickets').add({
          'title': _titleController.text,
          'description': _descriptionController.text,
          'priority': _priority,
          'category': _category,
          'raisedBy': widget.userEmail,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'updatedBy': 'None',
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
        title: Text('Raise a Ticket', style: GoogleFonts.montserrat( fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(onPressed: (){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AdminTicketPage()),
            );
          }, icon:Icon( Icons.open_in_browser))
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
                        style: TextStyle(
                          color: Colors.black, // Set the text input color
                          fontSize: 16, // Optional: Set the font size for the input text
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
                        style: TextStyle(
                          color: Colors.black, // Set the text input color
                          fontSize: 16, // Optional: Set the font size for the input text
                        ),
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
                          labelText: 'Category',
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
                        child: Text('Raise Ticket', style: GoogleFonts.montserrat()),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade700,
                            foregroundColor: Colors.white
                        ),
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
                      color: Colors.deepPurple.shade700

                  ),
                ),
                SizedBox(height: 16),
                Container(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child:ListView.builder(
                    itemCount: _tickets.length,
                    itemBuilder: (context, index) {
                      final ticket = _tickets[index];

                      // Safely retrieve 'createdAt' and 'updatedAt' with fallback to default strings
                      final createdAt = ticket['createdAt'] is Timestamp
                          ? (ticket['createdAt'] as Timestamp).toDate()
                          : null;
                      final updatedAt = ticket['updatedAt'] is Timestamp
                          ? (ticket['updatedAt'] as Timestamp).toDate()
                          : null;

                      // Default strings for null values
                      final createdAtText = createdAt != null
                          ? DateFormat('yyyy-MM-dd – kk:mm').format(createdAt)
                          : 'Unknown creation date';
                      final updatedAtText = updatedAt != null
                          ? DateFormat('yyyy-MM-dd – kk:mm').format(updatedAt)
                          : 'Unknown update date';

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
                                  ticket['title'] ?? 'No Title',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Spacer(),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(ticket['priority'] ?? 'Low'),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    ticket['priority'] ?? 'Low',
                                    style: GoogleFonts.montserrat(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Raised on $createdAtText',
                                  style: GoogleFonts.montserrat(color: Colors.black),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  ticket['description'] ?? 'No Description',
                                  style: GoogleFonts.montserrat(color: Colors.black),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(ticket['status'] ?? 'Pending'),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        ticket['status'] ?? 'Pending',
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
                                  'Updated At:\n $updatedAtText',
                                  style: GoogleFonts.montserrat(color: Colors.black),
                                ),
                                Text(
                                  'Updated By:\n${ticket['updatedBy'] ?? 'not yet '}',
                                  style: GoogleFonts.montserrat(color: Colors.black),
                                  softWrap: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )

                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
