import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:str_erp/members/expenses.dart';

class ExpenseListPage extends StatefulWidget {
  @override
  _ExpenseListPageState createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends State<ExpenseListPage> {
  String? _selectedExpenseHead;
  String? _selectedVendor;
  String? _selectedPaymentMode;
  String? _selectedSortOption;
  List<String> _expenseHeads = [];
  List<String> _vendors = [];
  List<String> _paymentModes = [];
  List<String> _sortOptions = ['All', 'Paid', 'Unpaid'];
  final Color backgroundColor = Color(0xFFFFFFFE); // Off white
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchDropdownValues();
    _selectedSortOption = 'All'; // Default to 'All'
  }

  Future<void> _fetchDropdownValues() async {
    try {
      var expenseHeadsSnapshot =
          await FirebaseFirestore.instance.collection('expense_heads').get();
      var vendorsSnapshot =
          await FirebaseFirestore.instance.collection('vendors').get();
      var paymentModesSnapshot =
          await FirebaseFirestore.instance.collection('payment_modes').get();

      setState(() {
        _expenseHeads = expenseHeadsSnapshot.docs
            .map((doc) => doc['name'] as String)
            .toList();
        _vendors =
            vendorsSnapshot.docs.map((doc) => doc['name'] as String).toList();
        _paymentModes = paymentModesSnapshot.docs
            .map((doc) => doc['name'] as String)
            .toList();
      });
    } catch (e) {
      print('Error fetching dropdown values: $e');
    }
  }

  Stream<QuerySnapshot> _getFilteredExpenses() {
    CollectionReference expensesCollection =
        FirebaseFirestore.instance.collection('expenses');

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

  Future<void> _markAsPaid(String expenseId) async {
    try {
      await FirebaseFirestore.instance
          .collection('expenses')
          .doc(expenseId)
          .update({
        'paid': true,
      });
    } catch (e) {
      print('Error marking expense as paid: $e');
    }
  }

  DateTime? _parseDate(dynamic dateField) {
    try {
      if (dateField is Timestamp) {
        return dateField.toDate();
      } else if (dateField is String) {
        // Try different date formats
        try {
          return DateFormat('dd-MM-yyyy').parse(dateField, true);
        } catch (e) {
          try {
            return DateFormat('yyyy-MM-dd').parse(dateField, true);
          } catch (e) {
            print('Error parsing date: $dateField');
          }
        }
      }
    } catch (e) {
      print('Error parsing date: $e');
    }
    return null; // Return null if parsing fails
  }

  Map<String, List<Map<String, dynamic>>> _groupExpensesByMonth(
      List<QueryDocumentSnapshot> docs) {
    Map<String, List<Map<String, dynamic>>> groupedExpenses = {};

    for (var doc in docs) {
      final expense = doc.data() as Map<String, dynamic>;
      final date = _parseDate(expense['date']);

      if (date == null) continue; // Skip if date is invalid

      final monthYear =
          '${DateFormat('MMMM yyyy').format(date)}'; // Use full month name and year

      if (!groupedExpenses.containsKey(monthYear)) {
        groupedExpenses[monthYear] = [];
      }

      groupedExpenses[monthYear]!.add({
        'id': doc.id,
        ...expense,
      });
    }

    return groupedExpenses;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expense List',
            style: GoogleFonts.montserrat(
                fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExpenseTrackerPage(),
            ),
          );
        },
        icon: Icon(
          Icons.playlist_add,
          color: Colors.white,
        ),
        label: Text(
          'Add New',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.teal,
        elevation: 4,
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
                    return Center(
                        child: Text('Error: ${snapshot.error}',
                            style: GoogleFonts.montserrat(color: Colors.red)));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                        child: Text('No expenses available',
                            style: GoogleFonts.montserrat(
                                fontSize: 18, color: Colors.grey)));
                  }

                  final expenses = snapshot.data!.docs;

                  // Group expenses by month
                  final groupedExpenses = _groupExpensesByMonth(expenses);

                  // Filter expenses based on the selected sort option
                  List<Map<String, dynamic>> filteredExpenses = [];
                  for (var monthExpenses in groupedExpenses.values) {
                    for (var expense in monthExpenses) {
                      final isPaid = expense['paid'] ?? false;
                      if (_selectedSortOption == 'All' ||
                          (_selectedSortOption == 'Paid' && isPaid) ||
                          (_selectedSortOption == 'Unpaid' && !isPaid)) {
                        filteredExpenses.add(expense);
                      }
                    }
                  }

                  return ListView(
                    children: [
                      for (var month in groupedExpenses.keys)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 16.0),
                              child: Text(
                                month,
                                style: GoogleFonts.montserrat(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            ...filteredExpenses
                                .where((expense) =>
                                    '${DateFormat('MMMM yyyy').format(_parseDate(expense['date'])!)}' ==
                                    month)
                                .map((expense) {
                              final expenseId = expense['id'];
                              final date = _parseDate(expense['date']);
                              final expenseHead =
                                  expense['expense_head'] ?? 'N/A';
                              final name = expense['name'] ?? 'N/A';
                              final amount =
                                  expense['amount']?.toString() ?? '0.0';
                              final vendor = expense['vendor'] ?? 'N/A';
                              final paymentMode =
                                  expense['payment_mode'] ?? 'N/A';
                              final detail = expense['detail'] ?? 'N/A';
                              final paid = expense['paid'] ?? false;

                              return Container(
                                margin: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 16),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.green.shade100,

                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Card(
                                  color: Colors.white,
                                  margin: EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 12.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                  child: Column(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade100,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                          ),
                                        ),
                                        padding: EdgeInsets.all(16.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal.shade800,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: paid
                                                    ? Colors.white
                                                    : Colors.teal,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: paid
                                                    ? Border.all(
                                                    color: Colors.teal)
                                                    : null,
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  onTap: paid
                                                      ? null
                                                      : () => _markAsPaid(
                                                          expenseId),
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 8),
                                                    child: Text(
                                                      paid
                                                          ? 'Paid'
                                                          : 'Mark as Paid',
                                                      style: TextStyle(
                                                        color: paid
                                                            ? Colors.teal
                                                            : Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Amount',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      SizedBox(height: 4),
                                                      Text(
                                                        '₹${amount}',
                                                        style: TextStyle(
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .teal.shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Date',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      SizedBox(height: 4),
                                                      Text(
                                                        date
                                                                ?.toLocal()
                                                                .toString()
                                                                .split(
                                                                    ' ')[0] ??
                                                            'N/A',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color:
                                                              Colors.grey[800],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 16),
                                            _buildInfoRow(
                                                'Expense Head', expenseHead),
                                            _buildInfoRow('Vendor', vendor),
                                            _buildInfoRow(
                                                'Payment Mode', paymentMode),
                                            StatefulBuilder(
                                              builder: (context, setState) {
                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _buildInfoRow(
                                                        'Detail',
                                                        detail.length > 50 &&
                                                                !_isExpanded
                                                            ? '${detail.substring(0, 50)}...'
                                                            : detail),
                                                    if (detail.length > 50)
                                                      TextButton.icon(
                                                        onPressed: () {
                                                          setState(() {
                                                            _isExpanded =
                                                                !_isExpanded;
                                                          });
                                                        },
                                                        icon: Icon(
                                                          _isExpanded
                                                              ? Icons
                                                                  .keyboard_arrow_up
                                                              : Icons
                                                                  .keyboard_arrow_down,
                                                          color: Colors.teal,
                                                        ),
                                                        label: Text(
                                                          _isExpanded
                                                              ? 'Show Less'
                                                              : 'Show More',
                                                          style: TextStyle(
                                                            color: Colors.teal,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList()
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.all(12.0),
      height: 120.0,
      decoration: BoxDecoration(
        color: Colors.teal,
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
            Container(
              width: 120, // Adjust width as needed
              child: _buildDropdown(
                label: 'Sort',
                value: _selectedSortOption,
                items: _sortOptions,
                onChanged: (value) {
                  setState(() {
                    _selectedSortOption = value;
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
                  _selectedSortOption = 'All';
                });
              },
              child: Text('Clear Filters',
                  style: GoogleFonts.montserrat(
                      fontSize: 16, color: Colors.white)),
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
        filled: true,
        fillColor: Colors.teal.shade100,
        labelText: label,
        labelStyle: GoogleFonts.montserrat(
            fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      value: value,
      items: items.isNotEmpty
          ? items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: GoogleFonts.montserrat()),
              );
            }).toList()
          : [
              DropdownMenuItem<String>(
                value: null,
                child:
                    Text('No items available', style: GoogleFonts.montserrat()),
              )
            ],
      onChanged: onChanged,
      isExpanded: true,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
