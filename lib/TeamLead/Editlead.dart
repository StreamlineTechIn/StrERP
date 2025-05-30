import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LeadDetailPage extends StatefulWidget {
  final Map<String, dynamic> leadData;
  final String leadId;

  LeadDetailPage({required this.leadData, required this.leadId});

  @override
  State<LeadDetailPage> createState() => _LeadDetailPageState();
}

class _LeadDetailPageState extends State<LeadDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _updateController = TextEditingController();
  final List<String> statusOptions = [
    'New',
    'Contacted',
    'In Discussion',
    'Qualified',
    'Lost'
  ];

  Future<void> _showEditDialog() async {
    final nameController =
        TextEditingController(text: widget.leadData['name'] ?? '');
    final phoneController =
        TextEditingController(text: widget.leadData['phone'] ?? '');
    final emailController =
        TextEditingController(text: widget.leadData['email'] ?? '');
    final addressController =
        TextEditingController(text: widget.leadData['address'] ?? '');
    final descriptionController =
        TextEditingController(text: widget.leadData['description'] ?? '');
    String currentStatus = widget.leadData['status'] ?? 'New';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Lead'),
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
              DropdownButtonFormField<String>(
                value: currentStatus,
                items: statusOptions.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  currentStatus = value!;
                },
                decoration: InputDecoration(labelText: 'Status'),
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
              await _firestore.collection('leads').doc(widget.leadId).update({
                'name': nameController.text,
                'phone': phoneController.text,
                'email': emailController.text,
                'address': addressController.text,
                'description': descriptionController.text,
                'status': currentStatus,
              });
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addUpdate() async {
    if (_updateController.text.isNotEmpty) {
      try {
        final DocumentSnapshot doc =
            await _firestore.collection('leads').doc(widget.leadId).get();
        final List<dynamic> existingUpdates =
            (doc.data() as Map<String, dynamic>)['updates'] ?? [];

        final update = {
          'text': _updateController.text,
          'timestamp': DateTime.now()
              .toIso8601String(), // Store as string instead of ServerTimestamp
          'type': 'Note',
        };

        existingUpdates.add(update);

        await _firestore.collection('leads').doc(widget.leadId).update({
          'updates': existingUpdates,
        });

        _updateController.clear();
      } catch (e) {
        print('Error adding update: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add update')),
        );
      }
    }
  }

  Future<void> _convertToClient() async {
    try {
      // Add to clients collection
      await _firestore.collection('clients').add({
        ...widget.leadData,
        'convertedAt': DateTime.now().toIso8601String(),
      });

      // Remove from leads collection
      await _firestore.collection('leads').doc(widget.leadId).delete();

      Navigator.pop(context);
    } catch (e) {
      print('Error converting to client: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to convert lead to client')),
      );
    }
  }

  Future<void> _removeLead() async {
    try {
      await _firestore.collection('leads').doc(widget.leadId).delete();
      Navigator.pop(context);
    } catch (e) {
      print('Error removing lead: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove lead')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lead Details',
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'edit':
                  await _showEditDialog();
                  break;
                case 'convert':
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Convert to Client'),
                      content: Text(
                          'Are you sure you want to convert this lead to a client?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _convertToClient();
                          },
                          child: Text('Convert'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  );
                  break;
                case 'delete':
                  await _removeLead();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Edit Lead'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'convert',
                child: ListTile(
                  leading: Icon(Icons.arrow_forward),
                  title: Text('Convert to Client'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Delete Lead'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal,
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('leads').doc(widget.leadId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
          
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final updates =
                  List<Map<String, dynamic>>.from(data['updates'] ?? []);
          
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Card(
                      color: Colors.white,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['name'] ?? 'Unknown',
                              style: GoogleFonts.montserrat(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Status: ${data['status'] ?? 'New'}',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.teal,
                              ),
                            ),
                            Divider(),
                            Text(
                              'Phone: ${data['phone'] ?? 'N/A'}',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'Email: ${data['email'] ?? 'N/A'}',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'Address: ${data['address'] ?? 'N/A'}',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text('Description:',
          
                              style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),),
                            Text(
                              data['description'] ?? 'No description available',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      'Updates',
                      style: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(
                      height: 250,
                      child: ListView.builder(
                        itemCount: updates.length,
                        itemBuilder: (context, index) {
                          final update = updates[index];
                          final timestamp =
                              DateTime.tryParse(update['timestamp'] ?? '');
                          final dateStr = timestamp != null
                              ? DateFormat('MMM dd, yyyy HH:mm').format(timestamp)
                              : 'Unknown date';
                          return Column(
                            children: [
                              Card(
                                color: Colors.white,
                                margin: EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: Icon(Icons.note, color: Colors.teal),
                                  title: Text(
                                    update['text'] ?? 'No details',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  subtitle: Text(dateStr),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              style: TextStyle(color: Colors.black),
                              controller: _updateController,
                              decoration: InputDecoration(
                                hintText: 'Add an update...',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 16),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          FloatingActionButton(
                            onPressed: _addUpdate,
                            child: Icon(Icons.send),
                            backgroundColor: Colors.teal,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
