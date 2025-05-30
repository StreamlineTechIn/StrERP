import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ExpenseListPageManager extends StatefulWidget {
  @override
  _ExpenseListPageManagerState createState() => _ExpenseListPageManagerState();
}

class _ExpenseListPageManagerState extends State<ExpenseListPageManager> {
  String? _selectedExpenseHead;
  String? _selectedVendor;
  String? _selectedPaymentMode;
  List<String> _expenseHeads = [];
  List<String> _vendors = [];
  List<String> _paymentModes = [];

  @override
  void initState() {
    super.initState();
    _fetchDropdownValues();
  }

  Future<void> _fetchDropdownValues() async {
    try {
      var expenseHeadsSnapshot = await FirebaseFirestore.instance.collection('expense_heads').get();
      var vendorsSnapshot = await FirebaseFirestore.instance.collection('vendors').get();
      var paymentModesSnapshot = await FirebaseFirestore.instance.collection('payment_modes').get();

      setState(() {
        _expenseHeads = expenseHeadsSnapshot.docs.map((doc) => doc['name'] as String).toList();
        _vendors = vendorsSnapshot.docs.map((doc) => doc['name'] as String).toList();
        _paymentModes = paymentModesSnapshot.docs.map((doc) => doc['name'] as String).toList();
      });
    } catch (e) {
      print('Error fetching dropdown values: $e');
    }
  }

  Stream<QuerySnapshot> _getFilteredExpenses() {
    CollectionReference expensesCollection = FirebaseFirestore.instance.collection('expenses');

    Query query = expensesCollection;

    if (_selectedExpenseHead != null && _selectedExpenseHead!.isNotEmpty) {
      query = query.where('expense_head', isEqualTo: _selectedExpenseHead);
    }

    if (_selectedVendor != null && _selectedVendor!.isNotEmpty) {
      query = query.where('vendor', isEqualTo: _selectedVendor);
    }

    if (_selectedPaymentMode != null && _selectedPaymentMode!.isNotEmpty) {
      query = query.where('payment_mode', isEqualTo: _selectedPaymentMode);
    }

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expense List', style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredExpenses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.montserrat(color: Colors.red)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No expenses available', style: GoogleFonts.montserrat(fontSize: 18, color: Colors.grey)));
                }

                final expenses = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index].data() as Map<String, dynamic>;
                    final date = expense['date'] ?? 'N/A';
                    final expenseHead = expense['expense_head'] ?? 'N/A';
                    final name = expense['name'] ?? 'N/A';
                    final amount = expense['amount']?.toString() ?? '0.0';
                    final vendor = expense['vendor'] ?? 'N/A';
                    final paymentMode = expense['payment_mode'] ?? 'N/A';
                    final detail = expense['detail'] ?? 'N/A';

                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blueAccent, Colors.deepPurple.shade300],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16.0),
                          title: Text(name, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date: $date', style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white70)),
                              Text('Expense Head: $expenseHead', style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white70)),
                              Text('Amount: \₹${amount}', style: GoogleFonts.montserrat(fontSize: 16, color: Colors.greenAccent)),
                              Text('Vendor: $vendor', style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white70)),
                              Text('Payment Mode: $paymentMode', style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white70)),
                              SizedBox(height: 8.0),
                              Text('Detail: $detail', style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.all(12.0),
      height: 120.0,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              width: 135, // Adjust width as needed
              child: _buildDropdown(
                label: 'Expense Head',
                value: _selectedExpenseHead,
                items: _expenseHeads,
                onChanged: (value) {
                  setState(() {
                    _selectedExpenseHead = value;
                  });
                },
              ),
            ),
            SizedBox(width: 12),
            Container(
              width: 90, // Adjust width as needed
              child: _buildDropdown(
                label: 'Vendor',
                value: _selectedVendor,
                items: _vendors,
                onChanged: (value) {
                  setState(() {
                    _selectedVendor = value;
                  });
                },
              ),
            ),
            SizedBox(width: 12),
            Container(
              width: 135, // Adjust width as needed
              child: _buildDropdown(
                label: 'Payment Mode',
                value: _selectedPaymentMode,
                items: _paymentModes,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMode = value;
                  });
                },
              ),
            ),
            SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedExpenseHead = null;
                  _selectedVendor = null;
                  _selectedPaymentMode = null;
                });
              },
              child: Text('Clear Filters', style: GoogleFonts.montserrat(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(fontSize: 12, color: Colors.white),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      value: value,
      items: items.isNotEmpty ? items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: GoogleFonts.montserrat()),
        );
      }).toList() : [DropdownMenuItem<String>(
        value: null,
        child: Text('No items available', style: GoogleFonts.montserrat()),
      )],
      onChanged: onChanged,
      isExpanded: true,
    );
  }
}
