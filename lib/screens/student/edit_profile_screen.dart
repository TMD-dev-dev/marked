import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialYear;
  final String initialClass;

  const EditProfileScreen(this.initialName, this.initialYear, this.initialClass, {super.key});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  String? selectedYear;
  String? selectedClass;
  List<String> classList = [];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    selectedYear = widget.initialYear;
    selectedClass = widget.initialClass;
    if (selectedYear != null) fetchClassNames(selectedYear!);
  }

  Future<void> fetchClassNames(String year) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection("classes").doc(year).get();
      if (doc.exists) {
        List<dynamic> fetchedClasses = doc["classList"];
        setState(() {
          classList = fetchedClasses.cast<String>();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching class names: $e");
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    String userId = FirebaseAuth.instance.currentUser!.uid;
    try {
      await FirebaseFirestore.instance.collection("users").doc(userId).update({
        "name": _nameController.text.trim(),
        "year": selectedYear,
        "className": selectedClass,
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Profile updated successfully")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Error updating profile")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF26C6DA), Color(0xFF00796B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text(
                        "Update Your Profile",
                        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal[700]),
                      ),
                      const SizedBox(height: 20),

                      // ✅ Name Field
                      _buildTextField(_nameController, "Full Name", Icons.person, "Enter your full name"),

                      // ✅ Year Dropdown
                      _buildDropdown("Year", selectedYear, ["1st", "2nd", "3rd", "4th"], (value) {
                        setState(() {
                          selectedYear = value!;
                          selectedClass = null;
                          fetchClassNames(value);
                        });
                      }),

                      // ✅ Class Dropdown
                      _buildDropdown("Class Name", selectedClass, classList, (value) {
                        setState(() {
                          selectedClass = value!;
                        });
                      }),

                      const SizedBox(height: 20),

                      // ✅ Save Button
                      ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          backgroundColor: Colors.teal[700],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: const Text("Save Changes", style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ✅ Cancel Button
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel", style: TextStyle(fontSize: 16, color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Helper function for text fields
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        validator: (value) => value!.isEmpty ? "$label cannot be empty" : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.teal),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  // ✅ Helper function for dropdowns
  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }
}
