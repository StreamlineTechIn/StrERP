import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminLeaveManagementPage extends StatefulWidget {
  @override
  _AdminLeaveManagementPageState createState() => _AdminLeaveManagementPageState();
}

class _AdminLeaveManagementPageState extends State<AdminLeaveManagementPage> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _allLeaveApplications = [];
  List<Map<String, dynamic>> _filteredLeaveApplications = [];
  String _selectedFilter = "Pending";
  final Color backgroundColor = Color(0xFFF2F3F8);

  Map<String, String> _memberNames = {}; // Cache for member names
  Map<String, Map<String, dynamic>> _memberDetails = {};
  @override
  void initState() {
    super.initState();
    _fetchAllLeaveApplications();
  }


  Future<void> _fetchMemberDetails() async {
    try {
      final membersSnapshot = await FirebaseFirestore.instance.collection('members').get();
      final Map<String, String> memberNames = {};
      final Map<String, Map<String, dynamic>> memberDetails = {};

      for (var memberDoc in membersSnapshot.docs) {
        final data = memberDoc.data() as Map<String, dynamic>?;
        final memberName = data?['Name'] ?? 'Unknown';
        memberNames[memberDoc.id] = memberName;

        // Store additional details
        memberDetails[memberDoc.id] = {
          'leaveBalances': data?['leaveBalances'] ?? {
            'Sick Leave': 3,
            'Casual Leave': 2,
            'Annual Leave': 30,
          }
        };
      }

      setState(() {
        _memberNames = memberNames;
        _memberDetails = memberDetails;
      });
    } catch (e) {
      print('Error fetching member details: $e');
    }
  }

  void _showLeaveDetailsModal(Map<String, dynamic> application) {
    final memberId = application['memberId'];
    final leaveBalances = _memberDetails[memberId]?['leaveBalances'] ?? {};
    final startDate = (application['startDate'] as Timestamp).toDate();
    final endDate = (application['endDate'] as Timestamp).toDate();
    final createdAt = (application['createdAt'] as Timestamp).toDate();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Leave Application Details',
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                _buildDetailRow('Name', application['raisedBy']),
                _buildDetailRow('Leave Type', application['type'] ?? 'Not Specified'),
                _buildDetailRow('Date Range',
                    '${DateFormat('yyyy-MM-dd').format(startDate)} - ${DateFormat('yyyy-MM-dd').format(endDate)}'
                ),
                _buildDetailRow('Duration',
                    '${endDate.difference(startDate).inDays + 1} day(s)'
                ),
                _buildDetailRow('Created At',
                    DateFormat('MMMM d, yyyy h:mm:ss a').format(createdAt)
                ),
                _buildDetailRow('Description', application['description']),
                SizedBox(height: 10),
                Text(
                  'Leave Balances:',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ..._buildLeaveBalanceRows(leaveBalances),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.check, color: Colors.white),
                      label: Text('Approve', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.pop(context);
                        _updateLeaveStatus(application, 'Approved');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: Icon(Icons.close, color: Colors.white),
                      label: Text('Reject', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.pop(context);
                        _updateLeaveStatus(application, 'Rejected');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLeaveBalanceRows(Map<String, dynamic> leaveBalances) {
    return leaveBalances.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              entry.key,
              style: GoogleFonts.montserrat(),
            ),
            Text(
              entry.key == 'Annual Leave'
                  ? '${entry.value}/30 days per year'
                  : '${entry.value}/${entry.key == 'Sick Leave' ? 3 : 2} days per month',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                color: _getLeaveBalanceColor(entry.value, entry.key),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getLeaveBalanceColor(dynamic value, String leaveType) {
    int limit = leaveType == 'Annual Leave' ? 30 : (leaveType == 'Sick Leave' ? 3 : 2);
    double percentage = (value as int) / limit;

    if (percentage >= 0.7) return Colors.green;
    if (percentage >= 0.4) return Colors.orange;
    return Colors.red;
  }



  void _filterApplications(String status) {
    setState(() {
      _selectedFilter = status;
      _filteredLeaveApplications = _allLeaveApplications
          .where((app) => app['status'] == status)
          .toList();
    });
  }

  Future<void> _updateLeaveStatus(Map<String, dynamic> application, String newStatus) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final memberId = application['memberId'];
      final updatedApplication = {
        ...application,
        'status': newStatus,
      };

      final memberDocRef = FirebaseFirestore.instance.collection('members').doc(memberId);
      final memberDoc = await memberDocRef.get();
      final data = memberDoc.data() as Map<String, dynamic>?;

      final leaveApplications = (data?['leaveApplications'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
          [];
      final index = leaveApplications.indexWhere((app) => app['createdAt'] == application['createdAt']);

      if (index != -1) {
        leaveApplications[index] = updatedApplication;
      }

      await memberDocRef.update({
        'leaveApplications': leaveApplications,
      });

      setState(() {
        _allLeaveApplications[_allLeaveApplications.indexOf(application)] = updatedApplication;
        _filteredLeaveApplications = _allLeaveApplications
            .where((app) => app['status'] == _selectedFilter)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating leave status: $e';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Leave Management', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal.shade200,
              backgroundColor,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: Text('Pending', style: TextStyle(color: _selectedFilter == 'Pending' ? Colors.white : Colors.white)),
                    selected: _selectedFilter == 'Pending',
                    selectedColor: Colors.orange,
                    onSelected: (bool selected) => _filterApplications('Pending'),
                  ),
                  ChoiceChip(
                    label: Text('Approved', style: TextStyle(color: _selectedFilter == 'Approved' ? Colors.white : Colors.white)),
                    selected: _selectedFilter == 'Approved',
                    selectedColor: Colors.green,
                    onSelected: (bool selected) => _filterApplications('Approved'),
                  ),
                  ChoiceChip(
                    label: Text('Rejected', style: TextStyle(color: _selectedFilter == 'Rejected' ? Colors.white : Colors.white)),
                    selected: _selectedFilter == 'Rejected',
                    selectedColor: Colors.red,
                    onSelected: (bool selected) => _filterApplications('Rejected'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _filteredLeaveApplications.isEmpty
                  ? Center(
                child: Text(
                  'No leave applications found.',
                  style: GoogleFonts.montserrat(fontSize: 18),
                ),
              )
                  : ListView.builder(
                itemCount: _filteredLeaveApplications.length,
                itemBuilder: (context, index) {
                  final application = _filteredLeaveApplications[index];
                  final memberId = application['memberId'];
                  final leaveBalances = _memberDetails[memberId]?['leaveBalances'] ?? {};
                  final startDate = (application['startDate'] as Timestamp).toDate();
                  final endDate = (application['endDate'] as Timestamp).toDate();
                  final status = application['status'];
                  final raisedBy = application['raisedBy'];
                  final type = application['type'] ?? 'Not Specified';

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.grey.shade200],
                        ),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        title: Text(
                          '$raisedBy',
                          style: GoogleFonts.montserrat(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              'Leave Type: $type',
                              style: GoogleFonts.montserrat(color: Colors.black),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Leave Balance: ${_getRemainingLeavesText(leaveBalances, type)}',
                              style: GoogleFonts.montserrat(
                                color: _getLeaveBalanceColor(
                                    leaveBalances[type] ?? 0,
                                    type
                                ),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Status: $status',
                              style: GoogleFonts.montserrat(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () => _showLeaveDetailsModal(application),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: Text(
                                'Details',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
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

  String _getRemainingLeavesText(Map<String, dynamic> leaveBalances, String type) {
    if (type == 'Annual Leave') {
      return '${leaveBalances[type] ?? 0}/30 days per year';
    }
    return '${leaveBalances[type] ?? 0}/${type == 'Sick Leave' ? 3 : 2} days per month';
  }

  Future<void> _fetchAllLeaveApplications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _fetchMemberDetails(); // Fetch both names and leave balances

      final QuerySnapshot membersSnapshot =
      await FirebaseFirestore.instance.collection('members').get();

      List<Map<String, dynamic>> leaveApplications = [];

      for (var memberDoc in membersSnapshot.docs) {
        final data = memberDoc.data() as Map<String, dynamic>?;
        final userLeaveApplications = data?['leaveApplications'] as List<dynamic>? ?? [];

        for (var application in userLeaveApplications) {
          leaveApplications.add({
            ...application as Map<String, dynamic>,
            'raisedBy': _memberNames[memberDoc.id] ?? 'Unknown',
            'memberId': memberDoc.id,
          });
        }
      }

      setState(() {
        _allLeaveApplications = leaveApplications;
        _filteredLeaveApplications = leaveApplications
            .where((app) => app['status'] == _selectedFilter)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching leave applications: $e';
        _isLoading = false;
      });
    }
  }
}
