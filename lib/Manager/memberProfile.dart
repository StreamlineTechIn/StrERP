import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../TeamLead/memberAttendance.dart';

class MemberProfilePage extends StatefulWidget {
  final String? email;

  const MemberProfilePage({Key? key, required this.email}) : super(key: key);

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage> {
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String? DocId;
  // Controllers for the fields
  late TextEditingController nameController;
  late TextEditingController salaryController;
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

  String authorizedValue = 'No'; // Default value for radio buttons
  bool isLoading = true;
  bool isEditable = false;
  List<Map<String, String>> qualifications = [];
  List<Map<String, String>> experiences = [];
  Map<String, dynamic>? userData;

  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Modified _fetchUserData() method
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
          salaryController =
              TextEditingController(text: userData?['Current Salary']);
          emailController =
              TextEditingController(text: userData?['email'] ?? '');
          panController = TextEditingController(text: userData?['PAN'] ?? '');
          bankAccController = TextEditingController(text: userData?['Bank_Acc_num'] ?? '');
          IFSCController = TextEditingController(text: userData?['IFSC'] ?? '');
          adharController =
              TextEditingController(text: userData?['adhar'] ?? '');
          phoneController =
              TextEditingController(text: userData?['Number'] ?? '');
          genderController =
              TextEditingController(text: userData?['Gender'] ?? '');
          dobController = TextEditingController(text: userData?['DOB'] ?? '');
          addressController =
              TextEditingController(text: userData?['address'] ?? '');
          positionController =
              TextEditingController(text: userData?['Position'] ?? '');
          startDateController =
              TextEditingController(text: userData?['StartDate'] ?? '');
          medicalController =
              TextEditingController(text: userData?['Medical'] ?? '');
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

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
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

      await _firestore.collection('members').doc(DocId).update({
        'name': nameController.text,
        'email': emailController.text,
        'Current Salary': salaryController.text,
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
        title:
            Text("Warning", style: GoogleFonts.montserrat(color: Colors.teal)),
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
        salaryController.text.isEmpty ||
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

  Widget _buildDynamicFields(
      String sectionTitle,
      List<Map<String, String>> list,
      List<String> fieldNames,
      Function onAdd,
      Function onRemove) {
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
                  sectionTitle == "Qualifications"
                      ? Icons.school_outlined
                      : Icons.work_outline,
                  color: Colors.teal,
                  size: 24,
                ),
                SizedBox(width: 10),
                Text(
                  sectionTitle,
                  style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (list.isEmpty && isEditable)
              Center(
                child: Text(
                  "No ${sectionTitle.toLowerCase()} added yet",
                  style: GoogleFonts.montserrat(
                      color: Colors.grey, fontStyle: FontStyle.italic),
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: TextFormField(
                                initialValue: item[fieldName],
                                enabled: isEditable,
                                style: TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  labelText: fieldName,
                                  labelStyle: TextStyle(color: Colors.teal),
                                  prefixIcon: Icon(getFieldIcon(fieldName),
                                      color: Colors.teal),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.teal),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        BorderSide(color: Colors.teal.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: Colors.teal, width: 2),
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
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          backgroundColor: Colors.teal,
          title: Text(
            "Member Profile",
            style: GoogleFonts.montserrat(
              fontSize: 20,
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
        // Position the FAB
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                                SizedBox(
                                  height: 10,
                                ),
                                Row(
                                  children: [
                                    Column(
                                      children: [
                                        CircleAvatar(
                                          radius: 30,
                                          backgroundColor: Colors.white,
                                          backgroundImage: profileImageUrl !=
                                                  null
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
                                      ],
                                    ),
                                    Spacer(),
                                    SizedBox(
                                      width: 200.0, // Set the desired width
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          try {
                                            // await Navigator.push(
                                            //   context,
                                            // //   MaterialPageRoute(
                                            // //       // builder: (context) =>
                                            // //       //     AttendanceForEmailPage(
                                            // //       //         email:widget.email!)),
                                            // );
                                          } catch (e) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'An error occurred: $e')),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10.0)),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16.0, horizontal: 20.0),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today,
                                                size: 20.0,
                                                color: Colors.white),
                                            Spacer(),
                                            Text(
                                              "Attendance",
                                              style: GoogleFonts.montserrat(
                                                  fontSize: 15.0,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 20,
                                ),
                                _buildTextField("Name", nameController, Icons.person),
                                _buildTextField("Email", emailController, Icons.email),
                                _buildTextField("Current Salary", salaryController, Icons.money),
                                _buildTextField("PAN", panController, Icons.credit_card),
                                _buildTextField("Aadhaar", adharController, Icons.security),
                                _buildTextField("Bank Account Number", bankAccController, Icons.business),
                                _buildTextField("IFSC Code", IFSCController, Icons.abc),
                                _buildTextField("Phone", phoneController, Icons.phone),

                                _buildDropdownField("Gender", genderController, ['Male', 'Female', 'Other']),
                                _buildDateField("Date of Birth", dobController, Icons.cake),
                                _buildTextField("Address", addressController, Icons.home, maxLines: 3),
                                _buildTextField("Position Applied For", positionController, Icons.work),
                                _buildDateField("Start Date", startDateController, Icons.date_range),
                                _buildRadioButtons(),
                                _buildTextField("Medical Condition", medicalController, Icons.medical_services, maxLines: 2),
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
                        // ElevatedButton.icon(
                        //   onPressed: isEditable ? _saveUserData : null,
                        //   icon: Icon(Icons.save),
                        //   label: Text(
                        //     "Save Changes",
                        //     style: GoogleFonts.montserrat(
                        //       fontWeight: FontWeight.bold,
                        //       fontSize: 16,
                        //     ),
                        //   ),
                        //   style: ElevatedButton.styleFrom(
                        //     backgroundColor: Colors.teal,
                        //     foregroundColor: Colors.white,
                        //     padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(30),
                        //     ),
                        //   ),
                        // ),
                        SizedBox(height: 30),
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
    IconData icon, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextFormField(
        controller: controller,
        enabled: isEditable,
        maxLines: maxLines,
        style: TextStyle(color: Colors.black),
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
                  title: Text(
                    'Yes',
                    style: TextStyle(color: Colors.black),
                  ),
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
                  title: Text(
                    'No',
                    style: TextStyle(color: Colors.black),
                  ),
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
