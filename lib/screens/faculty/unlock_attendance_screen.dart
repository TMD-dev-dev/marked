import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class UnlockAttendanceScreen extends StatefulWidget {
  final String courseId;

  const UnlockAttendanceScreen({super.key, required this.courseId});

  @override
  _UnlockAttendanceScreenState createState() => _UnlockAttendanceScreenState();
}

class _UnlockAttendanceScreenState extends State<UnlockAttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? sessionId;
  Position? facultyLocation;
  bool isSessionActive = false;
  bool isLoading = false;
  List<String> markedStudents = [];
  int countdown = 180; // 3 minutes timer

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDialog();
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showPermissionDialog(permanent: true);
      return;
    }

    _resumeOrStartSession();
  }

  void _showPermissionDialog({bool permanent = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Location Permission Required"),
        content: Text(
          permanent
              ? "Location permissions are permanently denied. Please enable them in settings."
              : "This app needs location access to unlock attendance. Please allow location access.",
        ),
        actions: [
          if (!permanent)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.requestPermission();
                _checkPermissions();
              },
              child: const Text("Allow"),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          if (permanent)
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text("Open Settings"),
            ),
        ],
      ),
    );
  }

  Future<void> _resumeOrStartSession() async {
    setState(() => isLoading = true);

    try {
      String today = DateFormat("dd-MM-yyyy").format(DateTime.now());

      QuerySnapshot sessionSnapshot = await _firestore
          .collection('courses')
          .doc(widget.courseId)
          .collection('attendance')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: today)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(1)
          .get();

      if (sessionSnapshot.docs.isNotEmpty) {
        var lastSession = sessionSnapshot.docs.first;
        var data = lastSession.data() as Map<String, dynamic>;

        if (data.containsKey('startTime')) {
          Timestamp startTime = data['startTime'];
          if (DateTime.now().difference(startTime.toDate()).inMinutes < 3) {
            sessionId = lastSession.id;
            facultyLocation = Position(
              latitude: data['facultyLocation']['latitude'],
              longitude: data['facultyLocation']['longitude'],
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            );

            isSessionActive = true;
            _listenForUpdates();
            _startCountdown();
          }
        }
      }

      if (!isSessionActive) {
        await _startSession();
      }
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ Error fetching session: $e");
      }
    }

    setState(() => isLoading = false);
  }

  Future<void> _startSession() async {
    setState(() => isLoading = true);

    facultyLocation = await _getCurrentLocation();

    if (facultyLocation == null) {
      setState(() => isLoading = false);
      return;
    }

    String sessionDate = DateFormat("dd-MM-yyyy").format(DateTime.now());
    String sessionKey = "${sessionDate}_${DateTime.now().millisecondsSinceEpoch}";

    DocumentReference sessionRef = _firestore
        .collection('courses')
        .doc(widget.courseId)
        .collection('attendance')
        .doc(sessionKey);

    await sessionRef.set({
      "startTime": Timestamp.now(),
      "endTime": null,
      "facultyLocation": {
        "latitude": facultyLocation!.latitude,
        "longitude": facultyLocation!.longitude
      },
      "isLocked": false,
      "markedStudents": {},
    });

    sessionId = sessionKey;
    isSessionActive = true;
    _listenForUpdates();
    _startCountdown();

    setState(() => isLoading = false);
  }

  Future<void> _endSession() async {
    if (sessionId == null) return;

    await _firestore
        .collection('courses')
        .doc(widget.courseId)
        .collection('attendance')
        .doc(sessionId)
        .update({
      "isLocked": true,
      "endTime": Timestamp.now(),
    });

    setState(() => isSessionActive = false);
    Navigator.pop(context);
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ Error getting location: $e");
      }
      return null;
    }
  }

  void _listenForUpdates() {
    if (sessionId == null) return;

    _firestore
        .collection('courses')
        .doc(widget.courseId)
        .collection('attendance')
        .doc(sessionId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          Map<String, dynamic>? data = snapshot.data();
          markedStudents = data?["markedStudents"]?.keys.toList() ?? [];
        });
      }
    });
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (countdown > 0 && isSessionActive) {
        setState(() => countdown--);
        _startCountdown();
      } else {
        _endSession();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Unlock Attendance")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isSessionActive ? "Session Active" : "No Active Session",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            "Time Left: ${countdown ~/ 60}:${(countdown % 60).toString().padLeft(2, '0')}",
            style: const TextStyle(fontSize: 16, color: Colors.red),
          ),
          const SizedBox(height: 20),
          const Text(
            "Marked Students",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: markedStudents.length,
              itemBuilder: (context, index) {
                return Card(
                  color: Colors.green.shade100,
                  child: ListTile(
                    title: Text("Roll No: ${markedStudents[index]}"),
                    trailing: const Icon(Icons.check, color: Colors.green),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _endSession,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("End Session"),
          ),
        ],
      ),
    );
  }
}