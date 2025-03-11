import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  _AddCourseScreenState createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final TextEditingController _courseCodeController = TextEditingController();
  final TextEditingController _courseNameController = TextEditingController();
  String? selectedYear;
  List<String> classList = [];
  List<String> selectedClasses = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = false;

  // Fetch classes based on selected year
  Future<void> _fetchClasses() async {
    if (selectedYear == null) return;
    try {
      DocumentSnapshot snapshot = await _firestore.collection('classes').doc(selectedYear).get();
      if (snapshot.exists) {
        List<dynamic> fetchedClasses = snapshot['classList'];
        setState(() {
          classList = List<String>.from(fetchedClasses);
          selectedClasses.clear();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching class list: $e");
      }
    }
  }

  // Save course to Firestore
  Future<void> _saveCourse() async {
    if (selectedYear == null || selectedClasses.isEmpty || _courseCodeController.text.isEmpty || _courseNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please fill all fields")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ User not authenticated. Please log in again.")),
        );
        return;
      }

      DocumentSnapshot userDoc = await _firestore.collection("users").doc(user.uid).get();
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ User data not found.")),
        );
        return;
      }

      String facultyUID = userDoc["uid"];

      await _firestore.collection('courses').add({
        'year': selectedYear,
        'classList': selectedClasses,
        'courseCode': _courseCodeController.text.trim(),
        'courseName': _courseNameController.text.trim(),
        'facultyId': facultyUID,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Course added successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (kDebugMode) {
        print("Error saving course: $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to add course")),
      );
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFB3E5FC), Color(0xFF03A9F4)], // Light Blue Gradient
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Main Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title
                      Text(
                        "Add Course",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blueAccent[100]),
                      ),
                      const SizedBox(height: 20),

                      // Year Dropdown
                      _buildDropdown("Select Year", selectedYear, ['1st', '2nd', '3rd', '4th'], (value) {
                        setState(() {
                          selectedYear = value;
                          selectedClasses.clear();
                          _fetchClasses();
                        });
                      }),
                      const SizedBox(height: 16),

                      // Multi-Select for Class Names
                      if (classList.isNotEmpty) ...[
                        const Text("Select Classes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Wrap(
                          spacing: 8.0,
                          children: classList.map((className) {
                            return FilterChip(
                              label: Text(className),
                              selected: selectedClasses.contains(className),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    selectedClasses.add(className);
                                  } else {
                                    selectedClasses.remove(className);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Course Code Input
                      _buildTextField(_courseCodeController, "Course Code", Icons.code),
                      const SizedBox(height: 16),

                      // Course Name Input
                      _buildTextField(_courseNameController, "Course Name", Icons.book),
                      const SizedBox(height: 24),

                      // Save & Cancel Buttons
                      isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _saveCourse,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              backgroundColor: Colors.blueAccent[100],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Save", style: TextStyle(fontSize: 16, color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              backgroundColor: Colors.redAccent[100],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Cancel", style: TextStyle(fontSize: 16, color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function for Dropdowns
  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: GoogleFonts.poppins()))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Colors.grey[200],
      ),
    );
  }

  // Helper function for TextFields
  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Colors.grey[200],
      ),
    );
  }
}
