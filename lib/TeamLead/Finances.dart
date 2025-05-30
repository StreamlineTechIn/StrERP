import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:str_erp/TeamLead/Salaries.dart';

import '../members/expenses.dart';
import '../members/showExpenses.dart';

class FinancePage extends StatefulWidget {
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final Color backgroundColor = const Color(0xFFFFFFFE);
  double totalExpense = 0.0;
 // Off white
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    fetchMonthlyExpenses();
    fetchTotalSalary();
  }

  double totalSalary = 0.0; // Add this at the top of _FinancePageState

  Future<void> fetchTotalSalary() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('members').get();

      double salarySum = 0.0;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        // Safely fetch Current Salary field
        String? currentSalary = data['Current Salary'] as String?;

        if (currentSalary != null) {
          salarySum += double.tryParse(currentSalary) ?? 0.0; // Convert to double safely
        }
      }

      setState(() {
        totalSalary = salarySum; // Update total salary
      });
    } catch (e) {
      print('Error fetching salary data: $e');
    }
  }


  Future<void> fetchMonthlyExpenses() async {
    try {
      // Get the current month and year
      DateTime now = DateTime.now();
      String currentMonth = DateFormat('MM').format(now);
      String currentYear = DateFormat('yyyy').format(now);

      // Fetch all documents in the expenses collection
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .get();

      double sum = 0.0;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String dateString = data['date'] ?? '';
        double amount = data['amount']?.toDouble() ?? 0.0;

        if (dateString.isNotEmpty) {
          // Parse the date string into a DateTime object
          DateTime parsedDate = DateFormat('dd-MM-yyyy').parse(dateString);

          // Check if the expense is in the current month and year
          if (DateFormat('MM').format(parsedDate) == currentMonth &&
              DateFormat('yyyy').format(parsedDate) == currentYear) {
            sum += amount;
          }
        }
      }

      setState(() {
        totalExpense = sum;
      });
    } catch (e) {
      print('Error fetching monthly expenses: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Overview'),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total expense this Month',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${totalExpense.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  Spacer(),
                  Text('view',style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    color: Colors.teal
                  ), ),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.arrowRight, color: Colors.teal),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExpenseListPage(
                            // Replace with the email you want to pass
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Salary to Pay',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${totalSalary.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          Spacer(),
                          Text('details', style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            color: Colors.teal,
                          )),
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.arrowRight, color: Colors.teal),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SalaryPage(
                                    // Replace with the email you want to pass
                                  ),
                                ),
                              ); // Navigate to expense page
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              color: Colors.teal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      // Open add transaction modal (placeholder)
                    },
                    child: const Text(
                      'Add Transaction',
                      style: TextStyle(color: Colors.teal, fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExpenseListPage(
                           // Replace with the email you want to pass
                          ),
                        ),
                      ); // Navigate to expense page
                    },
                    child: const Text(
                      'Expense Page',
                      style: TextStyle(color: Colors.teal, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

    );
  }
}
