import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LeaveApplicationPage extends StatefulWidget {
  final String? userEmail;

  LeaveApplicationPage({required this.userEmail});

  @override
  _LeaveApplicationPageState createState() => _LeaveApplicationPageState();
}

class _LeaveApplicationPageState extends State<LeaveApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  DateTimeRange? _dateRange;
  String _type = 'Sick Leave';
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _leaveApplications = [];
  final Color backgroundColor = Color(0xFFFFFFFE);  // Off white
  Map<String, int> _monthlyLimits = {
    'Sick Leave': 3,
    'Casual Leave': 2,
    'Annual Leave': 30, // Yearly limit
  };

  Map<String, int> _approvedLeaveDays = {
    'Sick Leave': 0,
    'Casual Leave': 0,
    'Annual Leave': 0,
  };
  int remainingDays = 5;// Maximum leave days per month

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final ScrollController _scrollController = ScrollController();
  bool _showFAB = false;
  @override
  void initState() {
    super.initState();
    _fetchLeaveApplications();
    _fetchLeaveApplications();

    _scrollController.addListener(() {
      setState(() {
        _showFAB = _scrollController.offset >50; // Show FAB after scrolling 200 pixels.
      });
    });
  }
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  int _calculateLeaveDays(DateTime start, DateTime end) {
    return end.difference(start).inDays + 1;
  }

  String _getRemainingDaysText(String leaveType) {
    final approved = _approvedLeaveDays[leaveType] ?? 0;
    final limit = _monthlyLimits[leaveType] ?? 0;
    if (leaveType == 'Annual Leave') {
      return '$approved/30 days per year';
    }
    return '$approved/${limit} days per month';
  }


  Future<void> _fetchLeaveApplications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: widget.userEmail)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        final DocumentSnapshot userDoc = userSnapshot.docs.first;
        final data = userDoc.data() as Map<String, dynamic>?;
        final leaves = List<Map<String, dynamic>>.from(data?['leaveApplications'] ?? []);

        // Reset counters
        _approvedLeaveDays = {
          'Sick Leave': 0,
          'Casual Leave': 0,
          'Annual Leave': 0,
        };

        // Calculate approved leaves for current month/year
        final now = DateTime.now();

        for (var leave in leaves) {
          if (leave['status'] == 'Approved') {
            final startDate = (leave['startDate'] as Timestamp).toDate();
            final endDate = (leave['endDate'] as Timestamp).toDate();

            // Handle legacy data where type might be missing
            String leaveType;
            if (leave['type'] == null) {
              // For legacy entries, default to "Sick Leave" or handle as needed
              leaveType = 'Sick Leave';

              // Optionally update the legacy entry with a type
              // You might want to do this in a separate maintenance function
              leave['type'] = leaveType;
            } else {
              leaveType = leave['type'] as String;
            }

            if (leaveType == 'Annual Leave') {
              // For annual leave, count if it's in the current year
              if (startDate.year == now.year) {
                _approvedLeaveDays[leaveType] = (_approvedLeaveDays[leaveType] ?? 0) +
                    _calculateLeaveDays(startDate, endDate);
              }
            } else {
              // For other leaves, count if it's in the current month
              if (startDate.month == now.month && startDate.year == now.year) {
                _approvedLeaveDays[leaveType] = (_approvedLeaveDays[leaveType] ?? 0) +
                    _calculateLeaveDays(startDate, endDate);
              }
            }
          }
        }

        setState(() {
          _leaveApplications = leaves;
        });
      }
    } catch (e) {
      print('Error details: $e'); // Add this for debugging
      setState(() {
        _errorMessage = 'Error fetching leave applications: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  Color _getLeaveStatusColor(String leaveType) {
    final approved = _approvedLeaveDays[leaveType] ?? 0;
    final limit = _monthlyLimits[leaveType] ?? 0;

    if (approved >= limit) return Colors.red;
    if (approved >= limit * 0.7) return Colors.orange;
    return Colors.green;
  }


  Future<void> _applyForLeave() async {
    if (!_formKey.currentState!.validate() || _dateRange == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newApplication = {
        'description': _descriptionController.text,
        'startDate': _dateRange!.start,
        'type':_type,
        'endDate': _dateRange!.end,
        'createdAt': Timestamp.now(),
        'status': 'Pending',
      };

      final QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: widget.userEmail)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        final DocumentSnapshot userDoc = userSnapshot.docs.first;

        await FirebaseFirestore.instance.collection('members').doc(userDoc.id).update({
          'leaveApplications': FieldValue.arrayUnion([newApplication]),
        });

        setState(() {
          _leaveApplications.add(newApplication);
          _descriptionController.clear();
          _dateRange = null;
          _isLoading = false;
        });
      } else {
        throw Exception('User not found.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error applying for leave: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteLeaveApplication(Map<String, dynamic> application) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('email', isEqualTo: widget.userEmail)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        final DocumentSnapshot userDoc = userSnapshot.docs.first;

        await FirebaseFirestore.instance.collection('members').doc(userDoc.id).update({
          'leaveApplications': FieldValue.arrayRemove([application]),
        });

        setState(() {
          _leaveApplications.remove(application);
          _isLoading = false;
        });
      } else {
        throw Exception('User not found.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error deleting leave application: $e';
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Pending':
      default:
        return Colors.orange;
    }
  }
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }


  Widget _buildLeaveTypeCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.teal.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available, color: Colors.teal.shade700),
              SizedBox(width: 10),
              Text(
                'Available Leaves:',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          // Sick Leave
          _buildLeaveTypeRow(
            'Sick Leave',
            Icons.healing,
            '${_approvedLeaveDays['Sick Leave'] ?? 0}/3 days per month',
            _getLeaveStatusColor('Sick Leave'),
          ),
          Divider(height: 20),
          // Casual Leave
          _buildLeaveTypeRow(
            'Casual Leave',
            Icons.event_busy,
            '${_approvedLeaveDays['Casual Leave'] ?? 0}/2 days per month',
            _getLeaveStatusColor('Casual Leave'),
          ),
          Divider(height: 20),
          // Annual Leave
          _buildLeaveTypeRow(
            'Annual Leave',
            Icons.beach_access,
            '${_approvedLeaveDays['Annual Leave'] ?? 0}/30 days per year',
            _getLeaveStatusColor('Annual Leave'),
          ),
            /*Divider(height: 20),
            _buildLeaveTypeRow(
            'Extra Credits',
            Icons.monetization_on,
              TempCredits.toStringAsFixed(2),
            Colors.green,
            ),*/
        ],
      ),
    );
  }

  Widget _buildLeaveTypeRow(String type, IconData icon, String balance, Color statusColor) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type,
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    balance,
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildLeaveApplicationsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _leaveApplications.length,
      itemBuilder: (context, index) {
        final application = _leaveApplications[index];
        final startDate = (application['startDate'] as Timestamp).toDate();
        final endDate = (application['endDate'] as Timestamp).toDate();
        final description = application['description'];
        final status = application['status'];
        // Handle null type with a default value
        final type = application['type'] ?? 'Sick Leave';

        return Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          padding: EdgeInsets.all(12),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leave from ${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Description: $description',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              Text(
                'Type: $type',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Status: $status',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: _getStatusColor(status),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Apply for Leave',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.teal,
      ),
      floatingActionButton: _showFAB
          ? FloatingActionButton(
        onPressed: _scrollToTop,
        backgroundColor: Colors.teal,
        child: Icon(Icons.arrow_upward, color: Colors.white),
      )
          : null,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Container(
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
            child: Column (
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              _buildLeaveTypeCard(),

            if (_errorMessage != null)
                  Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 20),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(DateTime.now().year + 1),
                          );
                          if (picked != null && picked != _dateRange) {
                            setState(() {
                              _dateRange = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _dateRange == null ? Colors.white : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _dateRange == null ? Colors.grey.shade300 : Colors.teal.shade400,
                            ),
                            boxShadow: _dateRange == null
                                ? []
                                : [BoxShadow(color: Colors.teal.shade200, blurRadius: 4)],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dateRange == null
                                    ? 'Select Date Range'
                                    : '${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}',
                                style: GoogleFonts.montserrat(fontSize: 16, color: _dateRange == null ? Colors.black87 : Colors.black),
                              ),
                              Icon(Icons.calendar_today, color: Colors.teal),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _type,

                        decoration: InputDecoration(
                          labelText: 'Leave Type',
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
                        items: ['Sick Leave', 'Casual Leave', 'Annual Leave', 'Emergency Leave'].map((priority) {
                          return DropdownMenuItem(

                            value: priority,
                            child: Text(priority),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _type = value!;
                          });
                        },
                        dropdownColor: Colors.white,
                        style: TextStyle(color: Colors.black),
                      ),
                      SizedBox(height: 20),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: GoogleFonts.montserrat(color: Colors.black),
                          fillColor: Colors.white, // Set fill color to white
                          filled: true,


                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white, width: 2),
        
                          ),
                          contentPadding: EdgeInsets.all(14),
                          hintText: 'Enter a brief description for your leave request...',
                          hintStyle: GoogleFonts.montserrat(color: Colors.grey[300]),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _applyForLeave,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.deepPurple.shade700,
                            foregroundColor: Colors.white,
        
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('Submit', style: GoogleFonts.montserrat(fontSize: 19,
                            fontWeight: FontWeight.bold,)),
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Your Leave Applications',
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 20),
                      _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : _leaveApplications.isEmpty
                          ? Center(
                        child: Text(
                          'No leave applications found',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                          : _buildLeaveApplicationsList(),
                    ],
                  ),
                ),
                SizedBox(height: 200)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
