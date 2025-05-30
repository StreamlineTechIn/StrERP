import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:str_erp/members/showExpenses.dart';

class ExpenseTrackerPage extends StatefulWidget {
  @override
  _ExpenseTrackerPageState createState() => _ExpenseTrackerPageState();
}

class _ExpenseTrackerPageState extends State<ExpenseTrackerPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  final TextEditingController _newExpenseHeadController = TextEditingController();
  final TextEditingController _newVendorController = TextEditingController();
  final TextEditingController _newPaymentModeController = TextEditingController();

  final Color backgroundColor = const Color(0xFFE8F5E9); // Light mint green
  final Color cardColor = const Color(0xFFF5F5F5); // Light grey
  final Color primaryTextColor = const Color(0xFF424242); // Dark grey
  final Color accentTextColor = const Color(0xFF00897B); // Muted teal
  final Color buttonColor = const Color(0xFF1D4C4F); // Amber
  final Color actionColor = const Color(0xFF009688); // Deep teal

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

  void _addNewValue(String collection, String value) async {
    try {
      await FirebaseFirestore.instance.collection(collection).add({'name': value});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Added successfully', style: GoogleFonts.montserrat()),
        backgroundColor: Colors.green,
      ));
      _fetchDropdownValues(); // Refresh dropdown values
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to add value: $e', style: GoogleFonts.montserrat()),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _showAddValueDialog(String collection, TextEditingController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add New Value', style: GoogleFonts.montserrat()),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'New Value',
              labelStyle: GoogleFonts.montserrat(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  _addNewValue(collection, controller.text);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Please enter a value', style: GoogleFonts.montserrat()),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              child: Text('Add', style: GoogleFonts.montserrat()),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel', style: GoogleFonts.montserrat()),
            ),
          ],
        );
      },
    );
  }

  void _submitExpense() async {
    if (_formKey.currentState!.validate()) {
      // Create a Map for expense data
      final expenseData = {
        'date': _dateController.text,
        'expense_head': _selectedExpenseHead,
        'name': _nameController.text,
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'vendor': _selectedVendor,
        'payment_mode': _selectedPaymentMode,
        'detail': _detailController.text,
      };

      try {
        // Add data to Firestore
        await FirebaseFirestore.instance
            .collection('expenses')
            .add(expenseData);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Expense added successfully', style: GoogleFonts.montserrat()),
          backgroundColor: Colors.green,
        ));
        // Clear form fields
        _formKey.currentState!.reset();
        setState(() {
          _selectedExpenseHead = null;
          _selectedVendor = null;
          _selectedPaymentMode = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to add expense: $e', style: GoogleFonts.montserrat()),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expense Tracker', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submitExpense,
        icon: Icon(
          Icons.add,
          color: Colors.white,
        ),
        label: Text(
          'Add',
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

      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: 'Expense Date *',
                        hintText: 'dd-mm-yyyy',
                        fillColor: Colors.white, // Set fill color to white
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelStyle: GoogleFonts.montserrat(color: Colors.black),
                      ),
                      keyboardType: TextInputType.datetime,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the date';
                        }
                        return null;
                      },
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _dateController.text =
                                DateFormat('dd-MM-yyyy').format(pickedDate);
                          });
                        }
                      },
                    ),
                    SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedExpenseHead,
                            items: _expenseHeads.map((head) {
                              return DropdownMenuItem<String>(
                                value: head,
                                child: Text(head, style: GoogleFonts.montserrat()),
                              );
                            }).toList(),
                            decoration: InputDecoration(
                              labelText: 'Expense Head *',
                              fillColor: Colors.white, // Set fill color to white
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              labelStyle: GoogleFonts.montserrat(color: Colors.black),
                            ),
                            validator: (value) {
                              if (value == null || value == '--Select--') {
                                return 'Please select an expense head';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setState(() {
                                _selectedExpenseHead = value;
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            _showAddValueDialog('expense_heads', _newExpenseHeadController);
                          },
                          child: Text('Add', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor, // Amber
                            foregroundColor: Colors.white, // Contrast for text
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),

                        ),
                      ],
                    ),
                    SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedVendor,
                            items: _vendors.map((vendor) {
                              return DropdownMenuItem<String>(
                                value: vendor,
                                child: Text(vendor, style: GoogleFonts.montserrat()),
                              );
                            }).toList(),
                            decoration: InputDecoration(
                              labelText: 'Vendor',
                              fillColor: Colors.white, // Set fill color to white
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              labelStyle: GoogleFonts.montserrat(color: Colors.black),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _selectedVendor = value;
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            _showAddValueDialog('vendors', _newVendorController);
                          },
                          child: Text('Add', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor, // Amber
                            foregroundColor: Colors.white, // Contrast for text
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),

                        ),
                      ],
                    ),
                    SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedPaymentMode,
                            items: _paymentModes.map((mode) {
                              return DropdownMenuItem<String>(
                                value: mode,
                                child: Text(mode, style: GoogleFonts.montserrat()),
                              );
                            }).toList(),
                            decoration: InputDecoration(
                              labelText: 'Payment Mode *',
                              fillColor: Colors.white, // Set fill color to white
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              labelStyle: GoogleFonts.montserrat(color: Colors.black),
                            ),
                            validator: (value) {
                              if (value == null || value == '--Select--') {
                                return 'Please select a payment mode';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setState(() {
                                _selectedPaymentMode = value;
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            _showAddValueDialog('payment_modes', _newPaymentModeController);
                          },
                          child: Text('Add', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor, // Amber
                            foregroundColor: Colors.white, // Contrast for text
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),

                        ),
                      ],
                    ),
                    SizedBox(height: 16.0),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Expense Name *',
                        fillColor: Colors.white, // Set fill color to white
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelStyle: GoogleFonts.montserrat(color: Colors.black),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the expense name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.0),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount *',
                        fillColor: Colors.white, // Set fill color to white
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelStyle: GoogleFonts.montserrat(color: Colors.black),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the amount';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.0),
                    TextFormField(
                      controller: _detailController,
                      decoration: InputDecoration(
                        labelText: 'Expense Detail',
                        fillColor: Colors.white, // Set fill color to white
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelStyle: GoogleFonts.montserrat(color: Colors.black),
                      ),
                    ),
                    SizedBox(height: 20.0),

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
