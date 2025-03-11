import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class AttendanceVerificationScreen extends StatefulWidget {
  final String courseId;
  final String studentRollNumber;

  const AttendanceVerificationScreen({
    super.key,
    required this.courseId,
    required this.studentRollNumber,
  });

  @override
  _AttendanceVerificationScreenState createState() =>
      _AttendanceVerificationScreenState();
}

class _AttendanceVerificationScreenState extends State<AttendanceVerificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  String statusMessage = "Fetching Location...";
  bool isWithinRange = false;
  bool showJustification = false;
  String? activeSessionId; // Stores session ID of an active session

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  // 🔹 Request Location Permission
  Future<void> _requestLocationPermission() async {
    PermissionStatus status = await Permission.location.request();
    if (status.isGranted) {
      _verifyAttendance();
    } else {
      setState(() {
        isLoading = false;
        statusMessage = "Location permission denied ❌";
      });
    }
  }

  Future<void> _verifyAttendance() async {
    try {
      // 🔹 Fetch student's current location
      Position studentLocation = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // 🔹 Fetch the latest active session
      QuerySnapshot sessionSnapshot = await _firestore
          .collection('courses')
          .doc(widget.courseId)
          .collection('attendance')
          .orderBy("startTime", descending: true)
          .limit(1)
          .get();

      if (sessionSnapshot.docs.isEmpty) {
        setState(() {
          isLoading = false;
          statusMessage = "No active session found ❌";
        });
        return;
      }

      var sessionDoc = sessionSnapshot.docs.first;
      Map<String, dynamic> sessionData = sessionDoc.data() as Map<String, dynamic>;

      // Check if session is still active
      if (sessionData['isLocked'] == true) {
        setState(() {
          isLoading = false;
          statusMessage = "Session is already closed ❌";
        });
        return;
      }

      activeSessionId = sessionDoc.id; // Store session ID

      // 🔹 Fetch faculty's location from the session
      double facultyLat = sessionData['facultyLocation']['latitude'];
      double facultyLng = sessionData['facultyLocation']['longitude'];

      // 🔹 Calculate distance
      double distance = Geolocator.distanceBetween(
        studentLocation.latitude,
        studentLocation.longitude,
        facultyLat,
        facultyLng,
      );

      if (distance <= 5) {
        // ✅ Mark Attendance (Student is within range)
        await _firestore
            .collection('courses')
            .doc(widget.courseId)
            .collection('attendance')
            .doc(activeSessionId)
            .update({
          "markedStudents.${widget.studentRollNumber}": true, // 🔥 Store attendance properly
        });

        setState(() {
          isWithinRange = true;
          statusMessage = "Attendance Marked Successfully ✅";
          isLoading = false;
        });

        // Navigate back after delay
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context);
        });
      } else {
        // ❌ Outside Classroom - Show Justification Option
        setState(() {
          isLoading = false;
          statusMessage = "Outside Classroom ❌";
          showJustification = true;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        statusMessage = "Error: Unable to fetch location!";
      });
    }
  }

  Future<void> _sendJustification() async {
    if (activeSessionId == null) return;

    await _firestore
        .collection('courses')
        .doc(widget.courseId)
        .collection('justifications')
        .doc(widget.studentRollNumber)
        .set({
      "message": "Student marked outside classroom",
      "timestamp": Timestamp.now(),
    });

    // Show confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Justification Sent")),
    );

    // Navigate back after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attendance Verification")),
      body: Center(
        child: isLoading
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(statusMessage, style: const TextStyle(fontSize: 18)),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isWithinRange ? Icons.check_circle : Icons.error,
              color: isWithinRange ? Colors.green : Colors.red,
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(statusMessage, style: const TextStyle(fontSize: 20)),

            // Show Justification Button if student is outside the classroom
            if (showJustification)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _sendJustification,
                  child: const Text("Send Justification"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}