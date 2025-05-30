import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ClientDetailPage extends StatefulWidget {
  final Map<String, dynamic> clientData;
  final String clientId;

  ClientDetailPage({required this.clientData, required this.clientId});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _updateController = TextEditingController();

  Future<void> _showEditDialog() async {
    final nameController =
        TextEditingController(text: widget.clientData['name'] ?? '');
    final phoneController =
        TextEditingController(text: widget.clientData['phone'] ?? '');
    final emailController =
        TextEditingController(text: widget.clientData['email'] ?? '');
    final addressController =
        TextEditingController(text: widget.clientData['address'] ?? '');
    final descriptionController =
        TextEditingController(text: widget.clientData['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Client'),
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
              await _firestore
                  .collection('clients')
                  .doc(widget.clientId)
                  .update({
                'name': nameController.text,
                'phone': phoneController.text,
                'email': emailController.text,
                'address': addressController.text,
                'description': descriptionController.text,
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
            await _firestore.collection('clients').doc(widget.clientId).get();
        final List<dynamic> existingUpdates =
            (doc.data() as Map<String, dynamic>)['updates'] ?? [];

        final update = {
          'text': _updateController.text,
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'Note',
        };

        existingUpdates.add(update);

        await _firestore.collection('clients').doc(widget.clientId).update({
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

  Future<void> _removeClient() async {
    try {
      await _firestore.collection('clients').doc(widget.clientId).delete();
      Navigator.pop(context);
    } catch (e) {
      print('Error removing client: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove client')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Client Details',
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
                case 'delete':
                  await _removeClient();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Edit Client'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Delete Client'),
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
            stream:
                _firestore.collection('clients').doc(widget.clientId).snapshots(),
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
                              'Converted: ${_formatConvertedDate(data['convertedAt'])}',
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
                            Text(
                              'Description:',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
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

  String _formatConvertedDate(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final DateTime convertedDate = DateTime.parse(timestamp);
      return DateFormat('dd/MM/yyyy').format(convertedDate);
    } catch (e) {
      return 'Unknown';
    }
  }
}
