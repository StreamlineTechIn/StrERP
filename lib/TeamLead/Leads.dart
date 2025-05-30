import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'Editlead.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firestore Leads',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: LeadsPage(),
    );
  }
}

class Lead {
  final String name;
  final String phone;
  final String email;
  final String address;
  final String status;
  final String description;

  Lead({
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.status,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'status': status,
      'description': description,
      'updates': [],
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class LeadsPage extends StatefulWidget {
  @override
  _LeadsPageState createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      String? filePath = result.files.single.path;
      if (filePath != null) {
        await _readAndUploadExcelFile(filePath);
      }
    }
  }

  Future<void> _readAndUploadExcelFile(String filePath) async {
    var file = File(filePath);
    var bytes = file.readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);

    if (excel.tables.isNotEmpty) {
      var sheet = excel.tables.values.first;
      bool isHeader = true;

      for (var row in sheet.rows) {
        if (isHeader) {
          isHeader = false;
          continue;
        }

        if (row.length >= 4) {
          final lead = Lead(
            name: row[0]?.value?.toString() ?? '',
            phone: row[1]?.value?.toString() ?? '',
            email: row[2]?.value?.toString() ?? '',
            address: row[3]?.value?.toString() ?? '',
            status: 'New',
            description: '',
          );
          await _firestore.collection('leads').add(lead.toMap());
        }
      }
    }
  }

  void _showAddLeadDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Lead'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: addressController,
                decoration: InputDecoration(labelText: 'Address'),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final lead = Lead(
                name: nameController.text,
                phone: phoneController.text,
                email: emailController.text,
                address: addressController.text,
                status: 'New',
                description: descriptionController.text,
              );
              await _firestore.collection('leads').add(lead.toMap());
              Navigator.pop(context);
            },
            child: Text('Add Lead'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Leads', style: GoogleFonts.montserrat(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),),
        backgroundColor: Colors.teal,
      ),
      body: Container(
        decoration:  BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal,
              Colors.white,
            ],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('leads').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading leads'));
            }

            final leads = snapshot.data?.docs ?? [];

            return ListView.builder(
              itemCount: leads.length,
              itemBuilder: (context, index) {
                final lead = leads[index];
                final data = lead.data() as Map<String, dynamic>;
                return Card(
                  color: Colors.white,
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    title: Text(data['name'] ?? '',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['email'] ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),),
                        Text('Status: ${data['status'] ?? 'New'}',
                            style: TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LeadDetailPage(
                            leadData: data,
                            leadId: lead.id,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _showAddLeadDialog,
            heroTag: 'addLead',
            backgroundColor: Colors.teal,
            child: Icon(Icons.person_add, color: Colors.white),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _pickExcelFile,
            heroTag: 'uploadFile',
            backgroundColor: Colors.teal,
            child: Icon(Icons.upload_file, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
