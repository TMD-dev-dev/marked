import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:marked/screens/student/attendance_verification_screen.dart';

class CourseAttendanceScreen extends StatefulWidget {
  final String courseId;
  final String courseCode;
  final String courseName;
  final String studentRollNumber;

  const CourseAttendanceScreen({
    super.key,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.studentRollNumber,
  });

  @override
  _CourseAttendanceScreenState createState() => _CourseAttendanceScreenState();
}

class _CourseAttendanceScreenState extends State<CourseAttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> classList = [];
  int totalSessions = 0;
  int sessionsAttended = 0;
  double attendancePercentage = 0.0;
  String instructorName = ""; // ✅ Store instructor name
  List<Map<String, dynamic>> attendanceHistory = [
  ]; // Stores attendance records

  @override
  void initState() {
    super.initState();
    _fetchCourseDetails();
    _fetchAttendanceRecords();
  }

  Future<void> _fetchCourseDetails() async {
    DocumentSnapshot doc = await _firestore.collection('courses').doc(
        widget.courseId).get();

    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // ✅ Fetch faculty name using facultyId
      String facultyName = "Unknown Faculty";
      if (data.containsKey("facultyId")) {
        DocumentSnapshot facultyDoc = await _firestore.collection("users").doc(
            data["facultyId"]).get();
        if (facultyDoc.exists) {
          facultyName = facultyDoc["name"] ?? "Unknown Faculty";
        }
      }

      setState(() {
        classList = List<String>.from(data["classList"]);
        instructorName = facultyName; // ✅ Store faculty name
      });
    }
  }

  Future<void> _fetchAttendanceRecords() async {
    QuerySnapshot sessionsSnapshot = await _firestore
        .collection('courses')
        .doc(widget.courseId)
        .collection('attendance')
        .get();

    int attendedCount = 0;
    List<Map<String, dynamic>> tempHistory = [];

    for (var sessionDoc in sessionsSnapshot.docs) {
      String sessionId = sessionDoc.id; // Example: "08-03-2024_1"
      String sessionDate = sessionId.split('_')[0]; // Extract "08-03-2024"
      Map<String, dynamic>? sessionData =
      sessionDoc.data() as Map<String, dynamic>?;

      // Read attendance for this student
      bool wasPresent = sessionData?["markedStudents"]?[widget
          .studentRollNumber] ?? false;
      if (wasPresent) attendedCount++;

      tempHistory.add({
        "date": sessionDate,
        "status": wasPresent,
      });
    }

    setState(() {
      attendanceHistory = tempHistory;
      totalSessions = sessionsSnapshot.docs.length;
      sessionsAttended = attendedCount;
      attendancePercentage =
      totalSessions > 0 ? (sessionsAttended / totalSessions) * 100 : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseCode,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[400], // ✅ Student dashboard color scheme
        actions: [
          TextButton.icon(
            onPressed: () {
              _fetchCourseDetails();
              _fetchAttendanceRecords();
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              "Refresh",
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB3E5FC), Color(0xFF03A9F4)], // Light Blue Gradient
                  begin: Alignment.bottomRight,
                  end: Alignment.topLeft,
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // ✅ Course Info Card with Faculty Name
                      Card(
                        color: Colors.blueAccent.shade400,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        elevation: 6,
                        child: ListTile(
                          title: Text(widget.courseName,
                              style: const TextStyle(fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          subtitle: Text("Classes: ${classList.join(
                              ", ")}\nFaculty: $instructorName",
                              style: const TextStyle(color: Colors.white70,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ✅ Attendance Summary Widgets
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _infoCard("Total Sessions", totalSessions.toString()),
                            _infoCard("Sessions Attended", sessionsAttended.toString()),
                            _infoCard("Attendance %",
                                "${attendancePercentage.toStringAsFixed(1)}%"),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ✅ Attendance History List
                      const Text("Attendance History",
                          style: TextStyle(fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 10),

                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: attendanceHistory.length,
                        itemBuilder: (context, index) {
                          var record = attendanceHistory[index];
                          bool isPresent = record["status"];
                          return Card(
                            color: isPresent ? Colors.greenAccent[200] : Colors.red[300],
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              title: Text(record["date"], style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                              trailing: Icon(
                                isPresent ? Icons.check_circle : Icons.cancel,
                                color: isPresent ? Colors.green[800] : Colors
                                    .red[800],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // ✅ Floating Action Button for Marking Attendance
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AttendanceVerificationScreen(
                    courseId: widget.courseId,
                    studentRollNumber: widget.studentRollNumber,
                  ),
            ),
          );
        },
        icon: const Icon(Icons.check),
        label: const Text("Mark Attendance"),
        backgroundColor: Colors.blue,
        elevation: 6,
      ),
    );
  }

// ✅ Reusable Info Card for Attendance Summary
  Widget _infoCard(String title, String value) {
    return Card(
      color: Colors.blue[600], // ✅ Soft Green Shade
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
