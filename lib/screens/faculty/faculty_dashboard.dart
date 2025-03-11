import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marked/screens/faculty/add_course_screen.dart';
import 'package:marked/screens/faculty/course_interaction_screen.dart';
import '../auth/login_screen.dart';
import 'edit_course_screen.dart';

class FacultyDashboard extends StatefulWidget {
  const FacultyDashboard({super.key});

  @override
  _FacultyDashboardState createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, List<Map<String, dynamic>>> coursesByYear = {};
  String facultyName = "Loading...";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFacultyName();
    _fetchFacultyCourses();
  }

  Future<void> _fetchFacultyCourses() async {
    setState(() => isLoading = true);
    User? faculty = _auth.currentUser;
    if (faculty == null) return;

    QuerySnapshot coursesSnapshot = await _firestore
        .collection("courses")
        .where("facultyId", isEqualTo: faculty.uid)
        .get();

    Map<String, List<Map<String, dynamic>>> tempCourses = {};
    Timestamp now = Timestamp.now();

    for (var doc in coursesSnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // ✅ Delete expired courses
      if (data.containsKey('deleteAt') && data['deleteAt'] != null) {
        Timestamp deleteAt = data['deleteAt'];
        if (deleteAt.compareTo(now) <= 0) {
          await _firestore.collection("courses").doc(doc.id).delete();
          continue; // Skip adding to UI
        }
      }

      String year = data['year'];
      if (!tempCourses.containsKey(year)) {
        tempCourses[year] = [];
      }
      tempCourses[year]!.add({
        "id": doc.id,
        "courseName": data["courseName"],
        "courseCode": data["courseCode"],
        "classList": data["classList"],
        "deleteAt": data.containsKey('deleteAt') ? data['deleteAt'] : null,
      });
    }
    setState(() {
      coursesByYear = tempCourses;
      isLoading = false;
    });
  }

  Future<void> _fetchFacultyName() async {
    User? faculty = _auth.currentUser;
    if (faculty == null) return;

    DocumentSnapshot facultyDoc =
    await _firestore.collection("users").doc(faculty.uid).get();
    if (facultyDoc.exists) {
      setState(() {
        facultyName = facultyDoc["name"];
      });
    }
  }

  void _confirmDeleteCourse(String courseId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Course?"),
        content: const Text("This course will be permanently deleted in 1 minute."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await _markCourseForDeletion(courseId);
              Navigator.pop(context);
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _markCourseForDeletion(String courseId) async {
    await _firestore.collection("courses").doc(courseId).update({
      "deleteAt": Timestamp.fromMillisecondsSinceEpoch(
          (Timestamp.now().millisecondsSinceEpoch) + (1 * 60 * 1000)), // 1 min for testing
    });
    _fetchFacultyCourses();
  }

  Future<void> _recoverCourse(String courseId) async {
    await _firestore.collection("courses").doc(courseId).update({
      "deleteAt": FieldValue.delete(), // ✅ Remove deleteAt field
    });
    _fetchFacultyCourses();
  }

  void _logout() async {
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
      extendBody: true, // This prevents overlap without breaking the design
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(facultyName),
              accountEmail: Text(_auth.currentUser?.email ?? "No Email"),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.person, size: 40),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: _logout, // ✅ Ensure this function is still in the code!
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(
          "Faculty Dashboard",
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
        ),
        backgroundColor: Colors.blue[400],
        elevation: 4,
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
          onRefresh: _fetchFacultyCourses,
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : coursesByYear.isEmpty
              ? const Center(child: Text("No courses added yet.", style: TextStyle(fontSize: 18, color: Colors.white)))
              : ListView(
            padding: const EdgeInsets.all(16),
            children: coursesByYear.keys.map((year) {
              return _buildYearSection(year, coursesByYear[year]!);
            }).toList(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddCourseScreen()),
          ).then((_) => _fetchFacultyCourses());
        },
        label: const Text("Add Course"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
    );
  }
  Widget _buildYearSection(String year, List<Map<String, dynamic>> courses) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 5,
      child: ExpansionTile(
        title: Text(
          "Year $year",
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[800]),
        ),
        children: courses.map((course) => _buildCourseCard(course)).toList(),
      ),
    );
  }
  Widget _buildCourseCard(Map<String, dynamic> course) {
    bool isMarkedForDeletion = course["deleteAt"] != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: isMarkedForDeletion ? Colors.grey[400] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(3, 3),
          ),
        ],
      ),
      child: ListTile(
        title: Text(course["courseName"],
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text("Course Code: ${course['courseCode']}\nClasses: ${course['classList'].join(" ")}"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: isMarkedForDeletion
                  ? null
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditCourseScreen(courseId: course["id"]),
                  ),
                ).then((_) => _fetchFacultyCourses());
              },
            ),
            isMarkedForDeletion
                ? IconButton(
              icon: const Icon(Icons.restore, color: Colors.green),
              onPressed: () => _recoverCourse(course["id"]),
            )
                : IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteCourse(course["id"]),
            ),
          ],
        ),
        onTap: isMarkedForDeletion
            ? null
            : () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseInteractionScreen(
                courseId: course["id"],
                courseCode: course["courseCode"],
                courseName: course["courseName"],
              ),
            ),
          );
        },
      ),
    );
  }
}
