import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import 'home_screen.dart';
import 'login_screen.dart';

class AuthController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // SIGN UP
  Future<void> signUp(String name, String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _db.collection('users').doc(cred.user!.uid).set({
        'name': name,
        'email': email,
        'role': 'student', // change in console for IT / manager / admin
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _auth.signOut(); // user must login manually

      Get.offAll(() => const LoginScreen());
      Get.snackbar('Account Created', 'Please login.');
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Sign Up Failed', e.message ?? e.code);
    }
  }

  // LOGIN
  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      Get.offAll(() => const HomeScreen());
    } on FirebaseAuthException {
      Get.snackbar('Login Failed', 'Incorrect email or password');
    }
  }

  // LOGIN STATUS
  Future<bool> isLoggedIn() async => _auth.currentUser != null;

  // CURRENT USER DATA
  Future<Map<String, dynamic>?> getCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data();
  }

  Future<String> getName() async =>
      (await getCurrentAccount())?['name'] ?? 'User';

  Future<String> getEmail() async =>
      (await getCurrentAccount())?['email'] ?? '';

  Future<String> getRole() async =>
      (await getCurrentAccount())?['role'] ?? 'student';

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
    Get.offAll(() => const LoginScreen());
  }

  // DELETE ACCOUNT
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).delete();
      await user.delete();
      Get.offAll(() => const LoginScreen());
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Error', e.message ?? e.code);
    }
  }
}