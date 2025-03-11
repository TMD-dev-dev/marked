import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EditCourseScreen extends StatefulWidget {
  final String courseId;

  const EditCourseScreen({super.key, required this.courseId});

  @override
  _EditCourseScreenState createState() => _EditCourseScreenState();
}

class _EditCourseScreenState extends State<EditCourseScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _courseCodeController = TextEditingController();
  final TextEditingController _courseNameController = TextEditingController();

  String? selectedYear;
  List<String> classList = [];
  List<String> selectedClasses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourseDetails();
  }

  Future<void> _loadCourseDetails() async {
    try {
      DocumentSnapshot doc =
      await _firestore.collection('courses').doc(widget.courseId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        setState(() {
          selectedYear = data['year'];
          selectedClasses = List<String>.from(data['classList']);
          _courseCodeController.text = data['courseCode'];
          _courseNameController.text = data['courseName'];
        });

        if (selectedYear != null) {
          _fetchClassNames(selectedYear!);
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error fetching course details: $e");
    }
    setState(() => isLoading = false);
  }

  Future<void> _fetchClassNames(String year) async {
    setState(() => classList = []);

    try {
      DocumentSnapshot doc =
      await _firestore.collection("classes").doc(year).get();
      if (doc.exists) {
        List<dynamic> fetchedClasses = doc["classList"];
        setState(() {
          classList = List<String>.from(fetchedClasses);
          selectedClasses =
              selectedClasses.where((cls) => classList.contains(cls)).toList();
        });
      }
    } catch (e) {
      if (kDebugMode) print("Error fetching class names: $e");
    }
  }

  Future<void> _saveChanges() async {
    if (selectedYear == null ||
        selectedClasses.isEmpty ||
        _courseCodeController.text.isEmpty ||
        _courseNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please fill all fields")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      await _firestore.collection('courses').doc(widget.courseId).update({
        'year': selectedYear,
        'classList': selectedClasses,
        'courseCode': _courseCodeController.text.trim(),
        'courseName': _courseNameController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Course updated successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (kDebugMode) print("Error updating course: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to update course")),
      );
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient Background
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
                elevation: 10,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title
                      Text(
                        "Edit Course",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent[100]),
                      ),
                      const SizedBox(height: 20),

                      // Year Dropdown
                      _buildDropdown("Select Year", selectedYear,
                          ['1st', '2nd', '3rd', '4th'], (value) {
                            setState(() {
                              selectedYear = value;
                              selectedClasses.clear();
                              _fetchClassNames(value!);
                            });
                          }),
                      const SizedBox(height: 16),

                      // Multi-Select for Class Names
                      if (classList.isNotEmpty) ...[
                        const Text("Select Classes",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
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
                      _buildTextField(
                          _courseCodeController, "Course Code", Icons.code),
                      const SizedBox(height: 16),

                      // Course Name Input
                      _buildTextField(
                          _courseNameController, "Course Name", Icons.book),
                      const SizedBox(height: 24),

                      // Update & Cancel Buttons
                      isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _saveChanges,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 30, vertical: 15),
                              backgroundColor: Colors.blueAccent[100],
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(12)),
                            ),
                            child: const Text("Update",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 30, vertical: 15),
                              backgroundColor: Colors.redAccent[100],
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(12)),
                            ),
                            child: const Text("Cancel",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white)),
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
  Widget _buildDropdown(
      String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem(
          value: item, child: Text(item, style: GoogleFonts.poppins())))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border:
        OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Colors.grey[200],
      ),
    );
  }

  // Helper function for TextFields
  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        border:
        OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Colors.grey[200],
      ),
    );
  }
}
