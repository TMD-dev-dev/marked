import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up a new user
  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
    String? role, // ✅ Allow null values here
    String? year,
    String? rollNumber,
    String? className,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Store user details in Firestore
        await _firestore.collection("users").doc(user.uid).set({
          "name": name,
          "email": email,
          "role": role,
          "year": year,
          "rollNumber": rollNumber,
          "className": className,
        });
      }
      return user;
    } catch (e) {
      if (kDebugMode) {
        print("Error during signup: $e");
      }
      return null;
    }
  }

  // Log in an existing user
  Future<User?> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      if (kDebugMode) {
        print("Error during login: $e");
      }
      return null;
    }
  }

  // Forgot Password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      if (kDebugMode) {
        print("Error during password reset: $e");
      }
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ✅ Fetch User Details
  Future<Map<String, dynamic>?> getUserDetails() async {
    User? user = _auth.currentUser;
    if (user == null) return null;

    DocumentSnapshot doc = await _firestore.collection("users").doc(user.uid).get();
    return doc.exists ? doc.data() as Map<String, dynamic>? : null;
  }

  // ✅ Get User Role
  Future<String?> getUserRole() async {
    User? user = _auth.currentUser;
    if (user == null) return null;

    DocumentSnapshot doc = await _firestore.collection("users").doc(user.uid).get();
    return doc.exists ? doc["role"] as String? : null;
  }
}
