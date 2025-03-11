import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:marked/screens/faculty/unlock_attendance_screen.dart';

class CourseInteractionScreen extends StatefulWidget {
  final String courseId;
  final String courseCode;
  final String courseName;

  const CourseInteractionScreen({
    super.key,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
  });

  @override
  _CourseInteractionScreenState createState() =>
      _CourseInteractionScreenState();
}

class _CourseInteractionScreenState extends State<CourseInteractionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> classList = [];
  List<String> rollNumbers = [];
  Map<String, String> studentNames = {};
  List<String> sessionDates = [];
  String facultyName = "Unknown"; // Default value if faculty is not found
  Map<String, Map<String, bool>> attendanceData = {};
  Map<String, double> attendancePercentage = {};
  Map<String, String> rollToNameMap = {}; // Store rollNumber -> Name mapping
  bool showNames = false; // Toggle for roll numbers or names
  bool isSessionActive = false;
  int totalSessions = 0;
  int countdown = 0;
  int totalStudents = 0; // ✅ Declare totalStudents

  @override
  void initState() {
    super.initState();
    _fetchCourseDetails();
    _fetchAttendanceRecords();
    _listenForSessionStatus();
    _fetchSessionStatus();
  }

  Future<void> _fetchCourseDetails() async {
    DocumentSnapshot doc = await _firestore.collection('courses').doc(widget.courseId).get();

    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List<String> fetchedClassList = List<String>.from(data["classList"]);

      // Fetch faculty UID (assuming it's stored in 'facultyId')
      String? facultyId = data["facultyId"];

      if (facultyId != null) {
        // Fetch faculty details from Firestore
        DocumentSnapshot facultyDoc = await _firestore.collection('users').doc(facultyId).get();
        if (facultyDoc.exists) {
          facultyName = facultyDoc["name"] ?? "Unknown";
        }
      }

      List<String> studentRollNumbers = [];
      int studentCount = 0;

      for (String className in fetchedClassList) {
        QuerySnapshot studentsSnapshot = await _firestore
            .collection('users')
            .where('className', isEqualTo: className)
            .where('role', isEqualTo: 'Student')
            .orderBy('rollNumber')
            .get();

        for (var studentDoc in studentsSnapshot.docs) {
          String rollNumber = studentDoc['rollNumber'];
          String studentName = studentDoc['name'];

          studentRollNumbers.add(rollNumber);
          rollToNameMap[rollNumber] = studentName;
        }

        studentCount += studentsSnapshot.docs.length;
      }

      setState(() {
        classList = fetchedClassList;
        totalStudents = studentCount;
        rollNumbers = studentRollNumbers;
      });
    }
  }

  Future<void> _fetchAttendanceRecords() async {
    QuerySnapshot sessionsSnapshot = await _firestore
        .collection('courses')
        .doc(widget.courseId)
        .collection('attendance')
        .get();

    Map<String, Map<String, bool>> tempAttendanceData = {};
    List<String> fetchedSessionIds = [];
    Map<String, int> studentPresentCount = {};

    for (var sessionDoc in sessionsSnapshot.docs) {
      String sessionId = sessionDoc.id;
      fetchedSessionIds.add(sessionId);

      Map<String, dynamic>? sessionData =
      sessionDoc.data() as Map<String, dynamic>?;

      Map<String, dynamic>? markedStudents =
      sessionData?["markedStudents"] as Map<String, dynamic>?;

      markedStudents?.forEach((rollNumber, isPresent) {
        if (!tempAttendanceData.containsKey(rollNumber)) {
          tempAttendanceData[rollNumber] = {};
          studentPresentCount[rollNumber] = 0;
        }
        tempAttendanceData[rollNumber]![sessionId] = isPresent;
        if (isPresent) {
          studentPresentCount[rollNumber] =
              (studentPresentCount[rollNumber] ?? 0) + 1;
        }
      });
    }

    setState(() {
      attendanceData = tempAttendanceData;
      sessionDates = fetchedSessionIds;
      totalSessions = fetchedSessionIds.length;

      attendancePercentage = {
        for (var roll in rollNumbers)
          roll: sessionDates.isEmpty
              ? 0.0
              : ((studentPresentCount[roll] ?? 0) / sessionDates.length) * 100
      };
    });
  }

  Future<void> _updateAttendance(
      String rollNumber, String sessionId, bool newValue) async {
    await _firestore
        .collection('courses')
        .doc(widget.courseId)
        .collection('attendance')
        .doc(sessionId)
        .set({
      "markedStudents": {rollNumber: newValue}
    }, SetOptions(merge: true));

    _fetchAttendanceRecords();
  }

  /// ✅ Fetch session status for FAB and refresh button
  Future<void> _fetchSessionStatus() async {
    QuerySnapshot sessionSnapshot = await _firestore
        .collection('courses')
        .doc(widget.courseId)
        .collection('attendance')
        .orderBy("startTime", descending: true)
        .limit(1)
        .get();

    if (sessionSnapshot.docs.isNotEmpty) {
      var lastSession = sessionSnapshot.docs.first;
      var data = lastSession.data() as Map<String, dynamic>;

      // If session is still active
      if (data["endTime"] == null) {
        int remainingSeconds = 180 -
            DateTime.now().difference((data["startTime"] as Timestamp).toDate()).inSeconds;

        setState(() {
          isSessionActive = true;
          countdown = remainingSeconds > 0 ? remainingSeconds : 0;
        });
      } else {
        setState(() {
          isSessionActive = false;
        });
      }
    } else {
      setState(() {
        isSessionActive = false;
      });
    }
  }

  void _listenForSessionStatus() {
    _firestore
        .collection('courses')
        .doc(widget.courseId)
        .collection('attendance')
        .orderBy("startTime", descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        var sessionData =
            snapshot.docs.first.data() as Map<String, dynamic>? ?? {};
        Timestamp? startTime = sessionData["startTime"];
        if (startTime != null &&
            DateTime.now().difference(startTime.toDate()).inMinutes < 3) {
          int remainingSeconds =
              180 - DateTime.now().difference(startTime.toDate()).inSeconds;
          setState(() {
            isSessionActive = true;
            countdown = remainingSeconds > 0 ? remainingSeconds : 0;
          });
        } else {
          setState(() {
            isSessionActive = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseCode,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
        backgroundColor: Colors.blue[500],
        actions: [
          TextButton.icon(
            onPressed: () async {
              _fetchCourseDetails();
              _fetchAttendanceRecords();
              await _fetchSessionStatus(); // ✅ Refreshes FAB state
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
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // ✅ Updated Info Cards
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _infoCard("Total Students", rollNumbers.length.toString()),
                            _infoCard("Sessions Taken", sessionDates.length.toString()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // ✅ Course Details Card
                      Card(
                        color: Colors.blueAccent.shade400,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          title: Text(
                            widget.courseName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Faculty: $facultyName", // ✅ Display faculty name
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "Classes: ${classList.join(", ")}",
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      // ✅ Attendance Data Table
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 15,
                          border: TableBorder.all(color: Colors.blue.shade300), // Light blue border
                          headingRowColor: WidgetStateProperty.all(Colors.blue.shade200), // Light blue header row
                          dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                                (Set<WidgetState> states) {
                              return Colors.blue.shade100; // Light blue row background
                            },
                          ),
                          columns: [
                            const DataColumn(label: Text("Roll No / Name", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text("Attendance %", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                            for (String sessionId in sessionDates)
                              DataColumn(label: Text(sessionId.split('_')[0], textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: rollNumbers.asMap().entries.map((entry) {
                            String rollNumber = entry.value;

                            return DataRow(
                              color: WidgetStateProperty.all(Colors.blue.shade50), // Lighter row background
                              cells: [
                                // ✅ Roll Number / Name Toggle
                                DataCell(
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        showNames = !showNames; // Toggle state
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                      child: Text(
                                        showNames ? (rollToNameMap[rollNumber] ?? rollNumber) : rollNumber,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                    ),
                                  ),
                                ),

                                // ✅ Attendance Percentage (Shows "N/A" if no sessions exist)
                                DataCell(
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      (totalSessions == 0 || attendancePercentage[rollNumber] == null)
                                          ? "N/A"  // ✅ Show "N/A" when no sessions
                                          : "${attendancePercentage[rollNumber]!.toStringAsFixed(1)}%",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: (attendancePercentage[rollNumber] ?? 0) >= 85
                                            ? Colors.green // 🟢 85% and above → Green
                                            : (attendancePercentage[rollNumber] ?? 0) >= 75
                                            ? Colors.yellow[700] // 🟡 75% - 84.99% → Yellow
                                            : Colors.red, // 🔴 Below 75% → Red
                                      ),
                                    ),
                                  ),
                                ),

                                // ✅ Attendance Checkboxes
                                for (String sessionId in sessionDates)
                                  DataCell(
                                    Center(
                                      child: Checkbox(
                                        value: attendanceData[rollNumber]?[sessionId] ?? false,
                                        onChanged: (newValue) {
                                          _updateAttendance(rollNumber, sessionId, newValue ?? false);
                                        },
                                        activeColor: Colors.green, // Green when checked
                                        checkColor: Colors.white,
                                        side: const BorderSide(color: Colors.blueGrey), // Grey outline when unchecked
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UnlockAttendanceScreen(courseId: widget.courseId),
            ),
          );
        },
        label: Text(
          isSessionActive ? "Session Active: ${countdown}s" : "Unlock Attendance",
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: isSessionActive ? Colors.green : Colors.blue,
        icon: const Icon(Icons.lock_open, size: 20),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

    );
  }

  Widget _infoCard(String title, String value) {
    return Card(
      color: Colors.blue[600], // Softer tone
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

}