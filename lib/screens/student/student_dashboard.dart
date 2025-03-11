import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marked/screens/student/edit_profile_screen.dart';
import '../auth/login_screen.dart';
import 'course_attendance_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? studentName;
  String? studentEmail;
  String? studentClass;
  String? studentYear;
  String? studentRollNumber;
  List<Map<String, dynamic>> enrolledCourses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStudentData();
  }

  Future<void> fetchStudentData() async {
    setState(() => isLoading = true);

    User? user = _auth.currentUser;
    if (user == null) return;

    DocumentSnapshot studentDoc =
    await _firestore.collection("users").doc(user.uid).get();

    if (studentDoc.exists) {
      Map<String, dynamic> studentData = studentDoc.data() as Map<String, dynamic>;

      setState(() {
        studentName = studentData["name"];
        studentEmail = studentData["email"];
        studentYear = studentData["year"];
        studentClass = studentData["className"];
        studentRollNumber = studentData["rollNumber"];
      });

      fetchEnrolledCourses();
    }
  }

  Future<void> fetchEnrolledCourses() async {
    QuerySnapshot courseSnapshot = await _firestore
        .collection("courses")
        .where("classList", arrayContains: studentClass)
        .get();

    setState(() {
      enrolledCourses = courseSnapshot.docs.map((doc) {
        return {"id": doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
      isLoading = false;
    });
  }

  void logout() async {
    await _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(studentName ?? "Loading..."),
              accountEmail: Text(studentEmail ?? ""),
              currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Edit Profile"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfileScreen(
                      studentName ?? "",
                      studentYear ?? "",
                      studentClass ?? "",
                    ),
                  ),
                ).then((_) => fetchStudentData());
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: logout,
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(
          "Student Dashboard",
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[400],
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB3E5FC), Color(0xFF03A9F4)], // Light Blue Gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: fetchEnrolledCourses,
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : enrolledCourses.isEmpty
              ? const Center(
            child: Text(
              "No enrolled courses",
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: enrolledCourses.length,
            itemBuilder: (context, index) {
              var course = enrolledCourses[index];

              return AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(3, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text(
                    course["courseName"],
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Course Code: ${course['courseCode']}"),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CourseAttendanceScreen(
                          courseId: course["id"],
                          courseCode: course["courseCode"],
                          courseName: course["courseName"],
                          studentRollNumber: studentRollNumber ?? "",
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
