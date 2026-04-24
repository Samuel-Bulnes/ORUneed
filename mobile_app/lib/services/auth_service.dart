/*
 * Samuel Bulnes
 * Senior Project
 * Authentication Service
 * Manages all user authentication operations
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

//***********************************************************************************
// Authentication service that manages all user authentication operations

class AuthService {
  // TESTING MODE: Set to false to skip email verification (for quick testing)
  // Change to true when ready for production
  static const bool enableEmailVerification = true;

  // Firebase Authentication instance for handling auth operations
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Firestore instance for storing user profile data
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream that emits authentication state changes (login/logout)
  // UI can listen to this to automatically update when user signs in/out
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Returns the currently authenticated Firebase user, or null if signed out
  User? get currentUser => _auth.currentUser;

  //*********************************************************************************
  // Creates user only in Firebase Auth + Sends verification
  // Creates user account in Firebase Auth and sends verification email
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Validate ORU domain email requirement
      if (!email.toLowerCase().endsWith('@oru.edu')) {
        throw Exception('Only @oru.edu emails are allowed');
      }

      // Create Firebase Auth user account
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      // Should never happen, but validated for safety
      if (user == null) throw Exception('Failed to create user');

      // Temporarily store user's name in Firebase Auth displayName
      await user.updateDisplayName(name);

      if (enableEmailVerification) {
        // Send verification email
        await user.sendEmailVerification();
        print('Verification email sent to: $email');

        // Immediately sign out the user so they MUST verify before logging in
        await _auth.signOut();
        print('User created (awaiting verification): $email');
      } else {
        // Testing mode: create user profile immediately without email verification
        print('User created (testing mode - no verification): $email');
        // Create Firestore profile on signup (instead of on first login)
        UserModel userData = UserModel(
          uid: user.uid,
          email: email,
          name: name,
          createdAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(user.uid).set(userData.toMap());
      }

    } catch (e) {
      print('Error in signUp: $e');
      rethrow; // Pass error back to UI
    }
  }

  //*********************************************************************************
  //Requires verified email + Creates Firestore profile
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Firebase Auth sign-in attempt
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user == null) throw Exception('Failed to sign in');

      // Refresh user's state (necessary to detect updated verification)
      await user.reload();
      user = _auth.currentUser;

      // Block sign-in if email is not verified (only in production mode)
      if (enableEmailVerification && user != null && !user.emailVerified) {
        await _auth.signOut();
        throw Exception(
          'Please verify your email before logging in. Check your inbox.',
        );
      }

      // After verification, check if user exists in Firestore
      DocumentSnapshot doc = await _firestore.collection('users').doc(user!.uid).get();

      UserModel userData;

      if (!doc.exists) {
        // First login after verification → create Firestore profile
        print('First login detected — creating Firestore profile');

        userData = UserModel(
          uid: user.uid,
          email: user.email!,
          name: user.displayName ?? 'User',
          createdAt: DateTime.now(),
        );

        // Save user profile to Firestore
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userData.toMap());

        print('Firestore profile created for: ${user.email}');
      } else {
        // User already has Firestore profile → load data
        userData = UserModel.fromMap(doc.data() as Map<String, dynamic>);
        print('Existing user logged in: ${user.email}');
      }

      return userData;

    } catch (e) {
      print('Error in signIn: $e');
      rethrow;
    }
  }

  //*********************************************************************************
  // Logs out the current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  //*********************************************************************************
  // Fetch current user data from Firestore
  Future<UserModel?> getCurrentUserData() async {
    try {
      User? user = currentUser;

      // No authenticated user
      if (user == null) return null;

      // Fetch user profile from Firestore
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) return null;

      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  //*********************************************************************************
  // Resend verification email
  Future<void> resendVerificationEmail() async {
    User? user = _auth.currentUser;

    // Only resend if user exists and hasn't verified yet
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
      print('Verification email resent');
    }
  }
}
