import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({Key? key}) : super(key: key);

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

DateTime currentDate = DateTime.now();

class _InvoicesPageState extends State<InvoicesPage> {
  final TextEditingController _discountController = TextEditingController(
      text: "0");
  final TextEditingController _clientController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController(
    text: "1. Payment Terms: Full payment is due within 100 days of the invoice date. Late payments may incur an additional 5% interest per month. \n"
        "2. Taxes and Charges: All applicable taxes (e.g., GST) are included in the total amount unless stated otherwise. Additional charges may apply for changes or extra services.",
  );
  final TextEditingController _serviceNameController = TextEditingController();
  final TextEditingController _serviceQuantityController = TextEditingController();
  final TextEditingController _servicePriceController = TextEditingController();

  final List<Map<String, dynamic>> _services = [];
  String quotationNumber = "STR${DateTime
      .now()
      .year}001";
  double _gst = 18.0;

  Uint8List? logoImage;
  Uint8List? signatureImage;
  Uint8List? templateImage;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      final logoBytes = await rootBundle.load(
          'assets/images/streamlinetechin.png');
      final signatureBytes = await rootBundle.load(
          'assets/images/signature.png');
      final templateBytes = await rootBundle.load('assets/images/Invoice.png');

      setState(() {
        logoImage = logoBytes.buffer.asUint8List();
        signatureImage = signatureBytes.buffer.asUint8List();
        templateImage = templateBytes.buffer.asUint8List();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading assets: $e')),
      );
    }
  }

  void _addService() {
    String name = _serviceNameController.text;
    int quantity = int.tryParse(_serviceQuantityController.text) ?? 0;
    double price = double.tryParse(_servicePriceController.text) ?? 0.0;

    if (name.isEmpty || quantity <= 0 || price <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid service details.')),
      );
      return;
    }

    setState(() {
      _services.add({'name': name, 'quantity': quantity, 'price': price});
      _serviceNameController.clear();
      _serviceQuantityController.clear();
      _servicePriceController.clear();
    });
  }

  void _saveInvoice() async {
    try {
      String client = _clientController.text.isNotEmpty
          ? _clientController.text
          : "No Client Name Provided";
      String address = _addressController.text.isNotEmpty ? _addressController
          .text : "No Address Provided";
      String note = _noteController.text.isNotEmpty
          ? _noteController.text
          : "No Notes";

      double subTotal = 0.0;
      for (var service in _services) {
        subTotal += service['quantity'] * service['price'];
      }

      double discount = double.tryParse(_discountController.text) ?? 0.0;
      double discountedTotal = subTotal - discount;

      double gstAmount = discountedTotal * (_gst / 100);
      double total = discountedTotal + gstAmount;

      await FirebaseFirestore.instance.collection('invoices').add({
        'quotationNumber': quotationNumber,
        'client': client,
        'address': address,
        'services': _services,
        'subTotal': subTotal,
        'discount': discount,
        'gst': gstAmount,
        'total': total,
        'note': note,
        'date': DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice saved successfully!')),
      );

      setState(() {
        _services.clear();
        _clientController.clear();
        _addressController.clear();
        _discountController.text = "0";
        _noteController.text =
        "1. Payment Terms: Full payment is due within 100 days of the invoice date. Late payments may incur an additional 5% interest per month. \n"
            "2. Taxes and Charges: All applicable taxes (e.g., GST) are included in the total amount unless stated otherwise. Additional charges may apply for changes or extra services.";
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving invoice: $e')),
      );
    }
  }

  Future<void> _generatePdf(Map<String, dynamic> invoice) async {
    if (logoImage == null || signatureImage == null || templateImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Assets are still loading. Please try again later.')),
      );
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          buildBackground: (context) =>
              pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(
                  pw.MemoryImage(templateImage!),
                  fit: pw.BoxFit.cover,
                ),
              ),
        ),
        build: (pw.Context context) =>
        [
          pw.Padding(
            padding: const pw.EdgeInsets.all(0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with Logo and Company Info
                pw.Container(
                  margin: pw.EdgeInsets.zero,
                  // Eliminates all margins around the image
                  padding: pw.EdgeInsets.only(top: 0),
                  // Optional: Ensures no padding at the top
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Image(
                        pw.MemoryImage(logoImage!),
                        height: 150, // Adjusted logo size
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Streamline Tech India',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text('Email: Streamlinetechin@gmail.com'),
                          pw.Text('Phone: +91 70 2020 4112'.padRight(39)),
                          pw.Text(
                            'Address: Kaustubh Appartment,'.padRight(36) +
                                '\n Sharddha colony mahabal road' +
                                '\n Jalgaon Maharashtra- 452001',
                            textAlign: pw.TextAlign.right,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Client and Quotation Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'To:',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 18),
                        ),
                        pw.Text(
                          invoice['client'],
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 16),
                        ),
                        pw.Text(
                          invoice['address'].split(',').join('\n'),
                          style: pw.TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Quotation No: ${invoice['quotationNumber']}',
                          style: pw.TextStyle(fontSize: 12),
                        ),
                        pw.Text(
                          'GSTIN : 27AAACH7409R1Z1',
                          style: pw.TextStyle(fontSize: 12),
                        ),
                        pw.Text(
                          'Date: ${DateFormat('dd MMM yyyy').format(
                              invoice['date'].toDate())}',
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 30),

                // Services Table
                pw.Table.fromTextArray(
                  headers: ['Service Name', 'Cost', 'Quantity', 'Total'],
                  data: [
                    ...invoice['services'].map((service) {
                      return [
                        service['name'],
                        '${service['price']}',
                        '${service['quantity']}',
                        '${(service['quantity'] * service['price'])
                            .toStringAsFixed(2)}',
                      ];
                    }).toList(),
                    [
                      '',
                      'Subtotal',
                      '',
                      '${invoice['subTotal'].toStringAsFixed(2)}'
                    ],
                    [
                      '',
                      'Discount',
                      '',
                      '-${invoice['discount'].toStringAsFixed(2)}'
                    ],
                    [
                      '',
                      'GST (${_gst.toString()}%)',
                      '',
                      '${invoice['gst'].toStringAsFixed(2)}'
                    ],
                    ['', 'Total', '', '${invoice['total'].toStringAsFixed(2)}'],
                  ],
                ),

                pw.SizedBox(height: 40),

                // Note Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Note:',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 16),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        invoice['note'],
                        style: pw.TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // Signature
                pw.Text(
                  'Best Regards,',
                  style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                ),
                pw.Image(
                  pw.MemoryImage(signatureImage!),
                  height: 50,
                ),
                pw.Text(
                  'Aditya Sharma,',
                  style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text('Invoices'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('invoices')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No invoices available.'));
                }

                final invoices = snapshot.data!.docs;
                void _updateInvoice(String docId) async {
                  try {
                    String client = _clientController.text;
                    String address = _addressController.text;
                    String note = _noteController.text;
                    double discount = double.tryParse(
                        _discountController.text) ?? 0.0;

                    double subTotal = 0.0;
                    for (var service in _services) {
                      subTotal += service['quantity'] * service['price'];
                    }

                    double discountedTotal = subTotal - discount;
                    double gstAmount = discountedTotal * (_gst / 100);
                    double total = discountedTotal + gstAmount;

                    await FirebaseFirestore.instance.collection('invoices').doc(
                        docId).update({
                      'client': client,
                      'address': address,
                      'services': _services,
                      'subTotal': subTotal,
                      'discount': discount,
                      'gst': gstAmount,
                      'total': total,
                      'note': note,
                      'date': DateTime.now(),
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Invoice updated successfully!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating invoice: $e')),
                    );
                  }
                }

                void _editInvoice(BuildContext context, Map<String, dynamic> invoice, String docId) {
                  _clientController.text = invoice['client'] ?? '';
                  _addressController.text = invoice['address'] ?? '';
                  _discountController.text = invoice['discount']?.toString() ?? '0.0';
                  _noteController.text = invoice['note'] ?? '';

                  _services.clear();
                  if (invoice['services'] is List) {
                    _services.addAll((invoice['services'] as List)
                        .map((e) => e as Map<String, dynamic>)
                        .toList());
                  }

                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor: Colors.white,
                        title: const Text(
                          'Edit Invoice',
                          style: TextStyle(color: Colors.black),
                        ),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: _clientController,
                                decoration: const InputDecoration(
                                  labelText: 'Client Name',
                                  labelStyle: TextStyle(color: Colors.black),
                                ),
                                style: const TextStyle(color: Colors.black),
                              ),
                              TextField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: 'Address',
                                  labelStyle: TextStyle(color: Colors.black),
                                ),
                                style: const TextStyle(color: Colors.black),
                              ),
                              TextField(
                                controller: _discountController,
                                decoration: const InputDecoration(
                                  labelText: 'Discount',
                                  labelStyle: TextStyle(color: Colors.black),
                                ),
                                style: const TextStyle(color: Colors.black),
                                keyboardType: TextInputType.number,
                              ),
                              TextField(
                                controller: _noteController,
                                decoration: const InputDecoration(
                                  labelText: 'Note',
                                  labelStyle: TextStyle(color: Colors.black),
                                ),
                                style: const TextStyle(color: Colors.black),
                                maxLines: 5,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Edit Services',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                              ..._services.map((service) {
                                final TextEditingController serviceQuantityController =
                                TextEditingController(text: service['quantity'].toString());
                                final TextEditingController servicePriceController =
                                TextEditingController(text: service['price'].toString());

                                return ListTile(
                                  title: Text(service['name'], style: const TextStyle(color: Colors.black)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller: serviceQuantityController,
                                        decoration: const InputDecoration(
                                          labelText: 'Quantity',
                                          labelStyle: TextStyle(color: Colors.black),
                                        ),
                                        style: const TextStyle(color: Colors.black),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            service['quantity'] = int.tryParse(value) ?? 0;
                                          });
                                        },
                                      ),
                                      TextField(
                                        controller: servicePriceController,
                                        decoration: const InputDecoration(
                                          labelText: 'Price',
                                          labelStyle: TextStyle(color: Colors.black),
                                        ),
                                        style: const TextStyle(color: Colors.black),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            service['price'] = double.tryParse(value) ?? 0.0;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _services.remove(service);
                                      });
                                    },
                                  ),
                                );
                              }),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      final TextEditingController newServiceNameController = TextEditingController();
                                      final TextEditingController newServiceQuantityController = TextEditingController();
                                      final TextEditingController newServicePriceController = TextEditingController();

                                      return AlertDialog(
                                        title: const Text('Add Service', style: TextStyle(color: Colors.black)),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: newServiceNameController,
                                              decoration: const InputDecoration(labelText: 'Service Name'),
                                            ),
                                            TextField(
                                              controller: newServiceQuantityController,
                                              decoration: const InputDecoration(labelText: 'Quantity'),
                                              keyboardType: TextInputType.number,
                                            ),
                                            TextField(
                                              controller: newServicePriceController,
                                              decoration: const InputDecoration(labelText: 'Price'),
                                              keyboardType: TextInputType.number,
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Cancel', style: TextStyle(color: Colors.teal)),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                _services.add({
                                                  'name': newServiceNameController.text,
                                                  'quantity': int.tryParse(newServiceQuantityController.text) ?? 0,
                                                  'price': double.tryParse(newServicePriceController.text) ?? 0.0,
                                                });
                                              });
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Add', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                child: const Text('Add Service', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel', style: TextStyle(color: Colors.teal)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _updateInvoice(docId);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                            child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      );
                    },
                  );
                }
                return ListView.builder(
                  itemCount: invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = invoices[index].data() as Map<
                        String,
                        dynamic>;
                    return ListTile(
                      title: Text(invoice['client'],
                        style: TextStyle(color: Colors.black),
                      ),
                      subtitle: Text(invoice['services']
                          ?.map((s) => s['name'])
                          .join(', ') ??
                          'No services available.'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal),
                            onPressed: () {
                              _generatePdf(invoice);
                            },
                            child: const Text('View Invoice',
                                style: TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal),
                            onPressed: () {
                              _editInvoice(
                                  context, invoice, invoices[index].id);
                            },
                            child: const Text(
                                'Edit', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor: Colors.white,
                        title: const Text(
                          'Create Invoice',
                          style: TextStyle(color: Colors.black),
                        ),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: _clientController,
                                decoration: const InputDecoration(
                                    labelText: 'Client Name',
                                  labelStyle: TextStyle(color: Colors.black)
                                ),
                                style: TextStyle(color: Colors.black),
                              ),
                              TextField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                    labelText: 'Address' ,
                                labelStyle: TextStyle(color: Colors.black)),
                                style: TextStyle(color: Colors.black),
                              ),

                              TextField(
                                controller: _noteController,
                                decoration: const InputDecoration(
                                    labelText: 'Note',
                                labelStyle: TextStyle(color: Colors.black)),
                                maxLines: 5,
                                style: TextStyle(color: Colors.black),
                              ),
                              TextField(
                                controller: _discountController,
                                decoration: const InputDecoration(
                                    labelText: 'Discount' ,
                                labelStyle:  TextStyle(color: Colors.black)),
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: Colors.black),
                              ),
                              const SizedBox(height: 20),
                              const Text('Add Services', style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                              TextField(
                                controller: _serviceNameController,
                                decoration: const InputDecoration(
                                    labelText: 'Service Name',
                                    labelStyle:  TextStyle(color: Colors.black)
                              ),
                                  style:  TextStyle(color: Colors.black)
                        ),
                              TextField(
                                controller: _serviceQuantityController,
                                decoration: const InputDecoration(
                                    labelText: 'Quantity',
                                    labelStyle:  TextStyle(color: Colors.black)),
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: Colors.black),
                              ),
                              TextField(
                                controller: _servicePriceController,
                                decoration: const InputDecoration(
                                    labelText: 'Price',
                                    labelStyle:  TextStyle(color: Colors.black)),
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: Colors.black),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal),
                                onPressed: _addService,
                                child: const Text('Add Service',
                                    style: TextStyle(color: Colors.white)),
                              ),
                              const SizedBox(height: 10),
                              ..._services.map((service) {
                                return ListTile(
                                  title: Text(service['name']),
                                  subtitle: Text(
                                      'Quantity: ${service['quantity']} | Price: ${service['price']}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      setState(() {
                                        _services.remove(service);
                                      });
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.teal),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal),
                            onPressed: () {
                              _saveInvoice();
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                                'Save', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text('Create New Invoice',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}