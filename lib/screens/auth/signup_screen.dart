import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../student/student_dashboard.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController rollNumberController = TextEditingController();

  String? selectedYear;
  String? selectedClass;
  List<String> classList = [];
  bool isLoading = false;
  bool showRollNumber = false;
  bool showClassDropdown = false;

  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeInAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> fetchClassNames(String year) async {
    setState(() => classList = []);
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection("classes").doc(year).get();
      if (doc.exists) {
        List<dynamic> fetchedClasses = doc["classList"];
        setState(() {
          classList = fetchedClasses.cast<String>();
          selectedClass = null;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching class names: $e");
      }
    }
  }

  void signUp() async {
    // Check if all required fields are filled based on the selected year
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty ||
        confirmPasswordController.text.trim().isEmpty ||
        selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please fill in all required fields!")),
      );
      return;
    }

    // If the user selects a year (1st, 2nd, 3rd, or 4th), roll number & class name must be provided
    if (selectedYear != "null" &&
        (rollNumberController.text.trim().isEmpty || selectedClass == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please enter your roll number and class!")),
      );
      return;
    }

    // Ensure passwords match
    if (passwordController.text.trim() != confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Passwords do not match!")),
      );
      return;
    }

    setState(() => isLoading = true);

    // Assign role based on year selection
    String? assignedRole = selectedYear == "null" ? null : "Student";

    // Call AuthService signUp()
    User? user = await _authService.signUp(
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
      role: assignedRole,
      year: selectedYear,
      rollNumber: selectedYear == "null" ? null : rollNumberController.text.trim(),
      className: selectedYear == "null" ? null : selectedClass,
    );

    setState(() => isLoading = false);

    if (user != null) {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set(
        {
          "uid": user.uid,
          "name": nameController.text.trim(),
          "email": emailController.text.trim(),
          "role": assignedRole,
          "year": selectedYear,
          "rollNumber": selectedYear == "null" ? null : rollNumberController.text.trim(),
          "className": selectedYear == "null" ? null : selectedClass,
        },
        SetOptions(merge: true),
      );

      if (assignedRole == "Student") {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const StudentDashboard()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Account created! Waiting for admin approval.")),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Signup failed. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFB2DFDB), Color(0xFF00796B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FadeTransition(
                opacity: _fadeInAnimation,
                child: Card(
                  elevation: 12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  shadowColor: Colors.black54,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Sign Up",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        const SizedBox(height: 20),

                        _buildTextField(nameController, "Full Name", Icons.person, "Enter your full name"),
                        _buildTextField(emailController, "Email", Icons.email, "Enter a valid email address", TextInputType.emailAddress),
                        _buildTextField(passwordController, "Password", Icons.lock, "At least 6 characters", TextInputType.visiblePassword, true),
                        _buildTextField(confirmPasswordController, "Confirm Password", Icons.lock, "Re-enter your password", TextInputType.visiblePassword, true),

                        _buildDropdown("Year", selectedYear, ["1st", "2nd", "3rd", "4th", "null"], (value) {
                          setState(() {
                            selectedYear = value!;
                            showRollNumber = value != "null";
                            showClassDropdown = false;
                            rollNumberController.clear();
                            selectedClass = null;
                            classList = [];
                          });

                          if (value != "null") fetchClassNames(value!);
                        }),

                        if (showRollNumber)
                          _buildTextField(rollNumberController, "Roll Number", Icons.confirmation_number, "Enter your roll number", TextInputType.text),

                        if (showRollNumber)
                          _buildDropdown("Class Name", selectedClass, classList, (value) {
                            setState(() {
                              selectedClass = value;
                              showClassDropdown = value != null;
                            });
                          }),

                        const SizedBox(height: 20),

                        isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                          onPressed: signUp,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            backgroundColor: Colors.teal,
                            elevation: 5,
                          ),
                          child: Text("Sign Up", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
                        ),

                        const SizedBox(height: 10),

                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                          },
                          child: Text("Already have an account? Login", style: GoogleFonts.poppins(color: Colors.teal, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, String hint, [TextInputType keyboardType = TextInputType.text, bool obscureText = false]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.teal),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: GoogleFonts.poppins()))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }
}
