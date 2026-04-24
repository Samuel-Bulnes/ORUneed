/*
 * Samuel Bulnes
 * Senior Project
 * User Model
 * Defines the structure of a user profile stored in Firestore
 */

//***********************************************************************************
// Stores personal information, activity stats, and account details
class UserModel {
  final String uid;           // Unique Firebase Auth user ID
  final String email;         // User's ORU email address
  final String name;          // User's full name
  final String? photoUrl;     // Optional profile photo URL
  final double rating;        // User's average rating (0.0 - 5.0)
  final int completedJobs;    // Total number of jobs user has completed
  final int postedJobs;       // Total number of jobs user has posted
  final DateTime createdAt;   // When the account was created

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.photoUrl,
    this.rating = 0.0,          // Default rating is 0
    this.completedJobs = 0,     // New users start with 0 completed jobs
    this.postedJobs = 0,        // New users start with 0 posted jobs
    required this.createdAt,
  });

  //********************************************************************************
  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'rating': rating,
      'completedJobs': completedJobs,
      'postedJobs': postedJobs,
      'createdAt': createdAt.toIso8601String(), // Convert DateTime to string for storage
    };
  }

  //********************************************************************************
  // Create from Firestore Map
  // Factory constructor that creates a UserModel from a Firestore Map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'],                   // Nullable, no default needed
      rating: (map['rating'] ?? 0.0).toDouble(),   // Ensure value is a double
      completedJobs: map['completedJobs'] ?? 0,
      postedJobs: map['postedJobs'] ?? 0,
      createdAt: DateTime.parse(map['createdAt']), // Convert string back to DateTime
    );
  }

  //********************************************************************************
  // Copy with modifications
  // Creates a new UserModel with optionally updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? photoUrl,
    double? rating,
    int? completedJobs,
    int? postedJobs,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      rating: rating ?? this.rating,
      completedJobs: completedJobs ?? this.completedJobs,
      postedJobs: postedJobs ?? this.postedJobs,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
// 86 lines of code on this file