import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

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
    emailController.dispose();
    super.dispose();
  }

  void resetPassword() async {
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please enter your email!")),
      );
      return;
    }

    setState(() => isLoading = true);

    await _authService.resetPassword(emailController.text.trim());

    setState(() => isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Reset link sent! Check your email.")),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ✅ Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFB2DFDB), Color(0xFF00796B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ✅ Main Content
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
                        // ✅ Title
                        Text(
                          "Forgot Password?",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Enter your registered email and we'll send you a reset link.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
                        ),
                        const SizedBox(height: 20),

                        // ✅ Email Input Field
                        _buildTextField(emailController, "Email", Icons.email, "Enter a valid email address", TextInputType.emailAddress),

                        const SizedBox(height: 20),

                        // ✅ Reset Button
                        isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                          onPressed: resetPassword,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            backgroundColor: Colors.teal,
                            elevation: 5,
                          ),
                          child: Text("Send Reset Link", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
                        ),

                        const SizedBox(height: 10),

                        // ✅ Back to Login
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                          },
                          child: Text("Back to Login", style: GoogleFonts.poppins(color: Colors.teal, fontSize: 14)),
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

  // ✅ Reusable Text Field
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, String hint, TextInputType keyboardType) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.teal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
