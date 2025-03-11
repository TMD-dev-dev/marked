import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../faculty/faculty_dashboard.dart';
import '../student/student_dashboard.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import '../../services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  void login() async {
    setState(() => isLoading = true);

    User? user = await _authService.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    setState(() => isLoading = false);

    if (user != null) {
      String? role = await _authService.getUserRole();
      if (role == 'Student') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => StudentDashboard()),
        );
      } else if (role == 'Faculty') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => FacultyDashboard()),
        );
      } else {
        _showSnackbar("Invalid role. Contact admin.");
      }
    } else {
      _showSnackbar("Login failed. Check credentials.");
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, textAlign: TextAlign.center)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB3E5FC), Color(0xFF03A9F4)], // Light Blue Gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SingleChildScrollView(
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Welcome!",
                        style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
              
                      // Email Field
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: "Email",
                          hintText: "Enter a valid email address",
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
              
                      // Password Field
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Password",
                          hintText: "At least 6 characters",
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
              
                      // Login Button
                      isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                        onPressed: login,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: const Color(0xFF0288D1), // Deep Blue
                        ),
                        child: const Text("Login", style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
              
                      const SizedBox(height: 10),
              
                      // Forgot Password
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                          );
                        },
                        child: const Text("Forgot Password?", style: TextStyle(color: Colors.blue)),
                      ),
              
                      // Sign Up
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignupScreen()),
                          );
                        },
                        child: const Text("Don't have an account? Sign up", style: TextStyle(color: Colors.blue)),
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
}
