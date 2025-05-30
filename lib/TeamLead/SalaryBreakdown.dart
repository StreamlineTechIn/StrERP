import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class SalarySlipPage extends StatelessWidget {
  final Map<String, dynamic> memberData;

  const SalarySlipPage({Key? key, required this.memberData}) : super(key: key);

  // Fetch salary from Firebase based on the email

  Future<String?> _fetchSalary(String email) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('members') // Your Firebase collection name
          .where('email', isEqualTo: email)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Assuming 'salary' is a field in the document
        return querySnapshot.docs.first.data()['Current Salary'];
      } else {
        return null; // No data found
      }
    } catch (e) {
      print('Error fetching data: $e');
      return null; // Return null in case of error
    }
  }

  @override
  Widget build(BuildContext context) {

    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: Text('Salary Slip', style: GoogleFonts.montserrat()),
        backgroundColor: Colors.teal,
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal,
              const Color(0xFFFFFFFE), // Off white
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Text(
                      'SALARY SLIP',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(lastMonth),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                    const Divider(thickness: 2, color: Colors.teal),

                    // Employee Details
                    _buildDetailRow('Employee Name', memberData['name']),
                    _buildDetailRow('Employee ID', memberData['EmpId']),
                    _buildDetailRow('Email', memberData['Email']),

                    const SizedBox(height: 16),

                    // Displaying the fetched salary using FutureBuilder
                    FutureBuilder<String?>(
                      future: _fetchSalary(memberData['Email']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        } else if (snapshot.hasData) {
                          final salary = snapshot.data;
                          if (salary != null) {
                            double salaryAmount = double.tryParse(salary.replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
                            return _buildDetailRow('Current Salary', formatter.format(salaryAmount));
                          } else {
                            return _buildDetailRow('Current Salary', 'Not available');
                          }
                        } else {
                          return _buildDetailRow('Current Salary', 'Not available');
                        }
                      },
                    ),

                    // Earnings Section
                    const SizedBox(height: 16),
                    _buildSectionHeader('Earnings Breakdown'),
                    _buildAmountRow('Regular Salary', formatter.format(memberData['regularSalary'])),
                    _buildAmountRow('Additional Earnings', formatter.format(memberData['additionalEarnings'])),
                    const Divider(thickness: 1, color: Colors.grey),
                    _buildAmountRow('Total Earnings', formatter.format(memberData['salary'])),

                    // Attendance Details
                    const SizedBox(height: 16),
                    _buildSectionHeader('Attendance'),
                    _buildDetailRow('Full Days', memberData['fullDays'].toString()),
                    _buildDetailRow('Half Days', memberData['halfDays'].toString()),

                    const Divider(thickness: 2, color: Colors.teal),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Salary Details'),
                    _buildDetailRow('Monthly Base Salary', formatter.format(memberData['monthlySalary'])),
                    _buildDetailRow('Daily Rate', formatter.format(memberData['monthlySalary'] / 23)),

                    const Divider(thickness: 2, color: Colors.teal),
                    // Net Salary
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Net Salary',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          Text(
                            formatter.format(memberData['salary']),
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              color: Colors.teal,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
