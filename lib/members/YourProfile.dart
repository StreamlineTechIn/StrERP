
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:str_erp/TeamLead/TLHome.dart';
import 'package:str_erp/members/memberHome.dart';

class YourProfilePage extends StatefulWidget {
  final String? email;

  const YourProfilePage({super.key, required this.email});

  @override
  State<YourProfilePage> createState() => _YourProfilePageState();
}

class _YourProfilePageState extends State<YourProfilePage> {
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

String? DocId;
  // Controllers for the fields
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController panController;
  late TextEditingController adharController;
  late TextEditingController phoneController;
  late TextEditingController genderController;
  late TextEditingController dobController;
  late TextEditingController addressController;
  late TextEditingController positionController;
  late TextEditingController startDateController;
  late TextEditingController medicalController;
  late TextEditingController bankAccController;
  late TextEditingController IFSCController;

  String authorizedValue = 'No';  // Default value for radio buttons
  bool isLoading = true;
  bool isEditable = false;
  List<Map<String, String>> qualifications = [];
  List<Map<String, String>> experiences = [];
  Map<String, dynamic>? userData;

  String? profileImageUrl;

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // Upload the image to Firebase Storage
      await _uploadImage(image.path);
    }
  }
  Future<void> _uploadImage(String filePath) async {
    try {
      File file = File(filePath);

      // Check if the file exists
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("File does not exist at path: $filePath"),
            backgroundColor: Colors.red,
          ),
        );
        return; // Exit the function if the file does not exist
      }

      String fileName = 'profile_images/${DocId}.jpg'; // Use a unique name for the image
      Reference ref = FirebaseStorage.instance.ref().child(fileName);

      // Upload the file
      await ref.putFile(file);
      String downloadUrl = await ref.getDownloadURL();

      // Update the Firestore document with the new image URL
      await _firestore.collection('members').doc(DocId).update({
        'profileImageUrl': downloadUrl,
      });

      // Update the local state
      setState(() {
        profileImageUrl = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Profile picture updated successfully!"),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to upload image: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('members')
          .where('email', isEqualTo: widget.email)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          DocId = snapshot.docs.first.id;
          userData = snapshot.docs.first.data() as Map<String, dynamic>;
          profileImageUrl = userData?['profileImageUrl'];
          nameController = TextEditingController(text: userData?['Name'] ?? '');
          emailController = TextEditingController(text: userData?['email'] ?? '');
          panController = TextEditingController(text: userData?['PAN'] ?? '');
          bankAccController = TextEditingController(text: userData?['Bank_Acc_num'] ?? '');
          IFSCController = TextEditingController(text: userData?['IFSC'] ?? '');
          adharController = TextEditingController(text: userData?['adhar'] ?? '');
          phoneController = TextEditingController(text: userData?['Number'] ?? '');
          genderController = TextEditingController(text: userData?['Gender'] ?? '');
          dobController = TextEditingController(text: userData?['DOB'] ?? '');
          addressController = TextEditingController(text: userData?['address'] ?? '');
          positionController = TextEditingController(text: userData?['Position'] ?? '');
          startDateController = TextEditingController(text: userData?['StartDate'] ?? '');
          medicalController = TextEditingController(text: userData?['Medical'] ?? '');
          authorizedValue = userData?['Authorized'] ?? 'No';

          // Properly convert qualifications data
          if (userData?['qualifications'] != null) {
            qualifications = (userData?['qualifications'] as List).map((item) {
              return {
                'Institute': item['Institute']?.toString() ?? '',
                'Year': item['Year']?.toString() ?? '',
                'Qualification': item['Qualification']?.toString() ?? ''
              };
            }).toList();
          }

          // Similarly for experiences
          if (userData?['experiences'] != null) {
            experiences = (userData?['experiences'] as List).map((item) {
              return {
                'Company': item['Company']?.toString() ?? '',
                'Position': item['Position']?.toString() ?? '',
                'Years': item['Years']?.toString() ?? ''
              };
            }).toList();
          }
        });

        
      }
    } catch (e) {
      print("Error fetching user data: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }


  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    if (!isEditable) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) {
      _showWarningModal("All fields are required!");
      return;
    }

    try {
      setState(() => isLoading = true);

      await _firestore
          .collection('members')
          .doc(DocId)
          .update({
        'Name': nameController.text,
        'email': emailController.text,
        'PAN': panController.text,
        'adhar': adharController.text,
        'Bank_Acc_num':bankAccController.text,
        'IFSC':IFSCController.text,
        'Number': phoneController.text,
        'Gender': genderController.text,
        'DOB': dobController.text,
        'address': addressController.text,
        'Position': positionController.text,
        'StartDate': startDateController.text,
        'Authorized': authorizedValue,
        'Medical': medicalController.text,
        'qualifications': qualifications,
        'experiences': experiences,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Profile updated successfully!"),
          backgroundColor: Colors.teal,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MemberHome()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save profile: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showWarningModal(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Warning", style: GoogleFonts.montserrat(color: Colors.teal)),
        content: Text(message, style: GoogleFonts.montserrat()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("OK", style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }
  bool _hasEmptyFields() {
    return nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        panController.text.isEmpty ||
        adharController.text.isEmpty ||
        phoneController.text.isEmpty ||
        genderController.text.isEmpty ||
        bankAccController.text.isEmpty ||
        IFSCController.text.isEmpty ||
        dobController.text.isEmpty ||
        addressController.text.isEmpty ||
        positionController.text.isEmpty ||
        startDateController.text.isEmpty ||
        medicalController.text.isEmpty;
  }
  Future<bool> _onWillPop() async {
    if (_hasEmptyFields()) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(
              "Missing Information",
              style: GoogleFonts.montserrat(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              "Please fill in all required fields before leaving.",
              style: GoogleFonts.montserrat(),
            ),
            actions: [
              TextButton(
                child: Text(
                  "OK",
                  style: GoogleFonts.montserrat(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return false;
    }
    return true;
  }

  void _addQualification() {
    setState(() {
      qualifications.add({'Institute': '', 'Year': '', 'Qualification': ''});
    });
  }

  void _removeQualification(int index) {
    setState(() {
      qualifications.removeAt(index);
    });
  }

  void _addExperience() {
    setState(() {
      experiences.add({'Company': '', 'Position': '', 'Years': ''});
    });
  }

  void _removeExperience(int index) {
    setState(() {
      experiences.removeAt(index);
    });
  }

  Widget _buildDynamicFields(String sectionTitle, List<Map<String, String>> list, List<String> fieldNames, Function onAdd, Function onRemove) {
    // Helper function to get appropriate icon for each field
    IconData getFieldIcon(String fieldName) {
      switch (fieldName.toLowerCase()) {
      // Qualification field icons
        case 'institute':
          return Icons.school;
        case 'year':
          return Icons.calendar_today;
        case 'qualification':
          return Icons.military_tech;

      // Experience field icons
        case 'company':
          return Icons.business;
        case 'position':
          return Icons.work;
        case 'years':
          return Icons.access_time;

        default:
          return Icons.label;
      }
    }

    return Card(
      color: Colors.white,
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  sectionTitle == "Qualifications" ? Icons.school_outlined : Icons.work_outline,
                  color: Colors.teal,
                  size: 24,
                ),
                SizedBox(width: 10),
                Text(
                  sectionTitle,
                  style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (list.isEmpty && isEditable)
              Center(
                child: Text(
                  "No ${sectionTitle.toLowerCase()} added yet",
                  style: GoogleFonts.montserrat(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic
                  ),
                ),
              ),
            ...list.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, String> item = entry.value;
              return Container(
                margin: EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.teal.shade100),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          ...fieldNames.map((fieldName) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: TextFormField(
                                initialValue: item[fieldName],
                                enabled: isEditable,
                                style: TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  labelText: fieldName,
                                  labelStyle: TextStyle(color: Colors.teal),
                                  prefixIcon: Icon(getFieldIcon(fieldName), color: Colors.teal),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.teal),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.teal.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.teal, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    list[index][fieldName] = value;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    if (isEditable)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: TextButton.icon(
                          onPressed: () => onRemove(index),
                          icon: Icon(Icons.delete_outline, color: Colors.red),
                          label: Text(
                            "Remove",
                            style: GoogleFonts.montserrat(color: Colors.red),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            if (isEditable)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: ElevatedButton.icon(
                    onPressed: () => onAdd(),
                    icon: Icon(Icons.add),
                    label: Text(
                      "Add ${sectionTitle.split(' ').first}",
                      style: GoogleFonts.montserrat(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
         title:  Text(
            "Member Profile",
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
                onPressed: isEditable ? _saveUserData : null,
                icon: Icon(
                  FontAwesomeIcons.floppyDisk,
                  color: isEditable ? Colors.white : Colors.teal,
                ))
          ],
          backgroundColor: Colors.teal,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            setState(() {
              isEditable = !isEditable;
            });
          },
          icon: Icon(
            isEditable ? Icons.cancel : Icons.edit,
            color: Colors.white,
          ),
          label: Text(
            isEditable ? "Cancel" : "Edit",
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: isEditable ? Colors.red : Colors.teal,
          elevation: 4,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.teal.shade700, Colors.teal.shade50],
            ),
          ),
          child: isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
            padding: EdgeInsets.all(7.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  SizedBox(height: 40),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    backgroundImage: profileImageUrl != null
                        ? NetworkImage(profileImageUrl!)
                        : null,
                    child: profileImageUrl == null
                        ? Icon(
                      Icons.person,
                      color: Colors.grey,
                      size: 40,
                    )
                        : null,
                  ),
                 isEditable ? ElevatedButton(
                    onPressed: isEditable ? _pickImage : null,
                    child: Text("Change Profile Picture"),
                  ):Container(),
                  SizedBox(height: 30),
                  Card(
                    color: Colors.white,
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(7),
                      child: Column(
                        children: [
                          _buildTextField("Name", nameController, Icons.person, validator: validateEmpty),
                          _buildTextField("Email", emailController, Icons.email, validator: validateEmail),
                          _buildTextField("PAN", panController, Icons.credit_card, validator: validatePAN),
                          _buildTextField("Aadhaar", adharController, Icons.security, validator: validateAadhaar),
                          _buildTextField("Bank Account Number", bankAccController, Icons.business, validator: validateAccount),
                          _buildTextField("IFSC Code", IFSCController, Icons.abc, validator: validateIFSC),
                          _buildTextField("Phone", phoneController, Icons.phone, validator: validatePhone),
                          _buildDropdownField("Gender", genderController, ['Male', 'Female', 'Other']),
                          _buildDateField("Date of Birth", dobController, Icons.cake),
                          _buildTextField("Address", addressController, Icons.home, maxLines: 1, validator: validateEmpty),
                          _buildTextField("Position Applied For", positionController, Icons.work, validator: validateEmpty),
                          _buildDateField("Start Date", startDateController, Icons.date_range),
                          _buildRadioButtons(),
                          _buildTextField("Medical Condition", medicalController, Icons.medical_services, maxLines: 1, validator: validateEmpty),

                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDynamicFields(
                    "Qualifications",
                    qualifications,
                    ['Institute', 'Year', 'Qualification'],
                    _addQualification,
                    _removeQualification,
                  ),
                  const SizedBox(height: 20),
                  _buildDynamicFields(
                    "Experiences",
                    experiences,
                    ['Company', 'Position', 'Years'],
                    _addExperience,
                    _removeExperience,
                  ),
                  SizedBox(height: 20),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      IconData icon, 
      {
        int maxLines = 1,
        String? Function(String?)? validator,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextFormField(
        controller: controller,
        enabled: isEditable,
        maxLines: maxLines,
        style: TextStyle(color: Colors.black),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.teal),
          prefixIcon: Icon(icon, color: Colors.teal),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.teal),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.teal.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.teal, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  String? validateEmpty(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Cannot be Empty";
    }
    return null;
  }
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  String? validateSalary(String? value) {
    if (value == null || value.isEmpty) return 'Salary is required';
    final salary = double.tryParse(value);
    if (salary == null || salary <= 0) return 'Enter a valid salary';
    return null;
  }

  String? validatePAN(String? value) {
    if (value == null || value.isEmpty) return 'PAN is required';
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    if (!panRegex.hasMatch(value)) return 'Invalid PAN format';
    return null;
  }

  String? validateAadhaar(String? value) {
    if (value == null || value.isEmpty) return 'Aadhaar is required';
    final aadhaarRegex = RegExp(r'^\d{12}$');
    if (!aadhaarRegex.hasMatch(value)) return 'Invalid Aadhaar number';
    return null;
  }

  String? validateAccount(String? value) {
    if (value == null || value.isEmpty) return 'Account number is required';
    final accountRegex = RegExp(r'^\d{9,18}$');
    if (!accountRegex.hasMatch(value)) return 'Invalid account number';
    return null;
  }

  String? validateIFSC(String? value) {
    if (value == null || value.isEmpty) return 'IFSC code is required';
    final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    if (!ifscRegex.hasMatch(value)) return 'Invalid IFSC code';
    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    final phoneRegex = RegExp(r'^[6-9]\d{9}$');
    if (!phoneRegex.hasMatch(value)) return 'Invalid phone number';
    return null;
  }

  String? validateDOB(DateTime? dob) {
    if (dob == null) return 'Date of birth is required';
    final today = DateTime.now();
    final age = today.year - dob.year - (today.month < dob.month || (today.month == dob.month && today.day < dob.day) ? 1 : 0);
    if (age < 18) return 'Must be at least 18 years old';
    return null;
  }

  String? validateStartDate(DateTime? startDate) {
    if (startDate == null) return 'Start date is required';
    if (startDate.isBefore(DateTime.now())) return 'Start date cannot be in the past';
    return null;
  }


  Widget _buildDateField(
      String label,
      TextEditingController controller,
      IconData icon,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextFormField(
        style: TextStyle(color: Colors.black),
        controller: controller,
        enabled: isEditable,
        readOnly: true,
        onTap: () => _selectDate(context, controller),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "$label is required";
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.teal),
          prefixIcon: Icon(icon, color: Colors.teal),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.teal.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.teal, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDropdownField(
      String label,
      TextEditingController controller,
      List<String> items,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: DropdownButtonFormField<String>(
        value: controller.text.isEmpty ? null : controller.text,
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: TextStyle(color: Colors.black)),
          );
        }).toList(),
        onChanged: isEditable
            ? (String? newValue) {
          setState(() {
            controller.text = newValue ?? '';
          });
        }
            : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.teal),
          prefixIcon: Icon(Icons.person_outline, color: Colors.teal),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.teal.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.teal, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,

        ),
        dropdownColor: Colors.white,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "$label is required";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildRadioButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
          "Are you legally authorized to work?",
          style: TextStyle(
            color: Colors.teal,
            fontSize: 16,
          ),
                ),
        ),
      Row(
          children: [
      Expanded(
      child: RadioListTile<String>(
          title: Text('Yes',style: TextStyle(color: Colors.black),),
      value: 'Yes',
      groupValue: authorizedValue,
      onChanged: isEditable
          ? (String? value) {
        setState(() {
          authorizedValue = value!;
        });
      }
          : null,
      activeColor: Colors.teal,
    ),
    ),
            Expanded(
              child: RadioListTile<String>(
                title: Text('No',style: TextStyle(color: Colors.black),),
                value: 'No',
                groupValue: authorizedValue,
                onChanged: isEditable
                    ? (String? value) {
                  setState(() {
                    authorizedValue = value!;
                  });
                }
                    : null,
                activeColor: Colors.teal,
              ),
            ),
          ],
      ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    panController.dispose();
    adharController.dispose();
    phoneController.dispose();
    genderController.dispose();
    dobController.dispose();
    addressController.dispose();
    positionController.dispose();
    startDateController.dispose();
    medicalController.dispose();
    super.dispose();
  }
}

