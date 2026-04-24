/*
 * Samuel Bulnes
 * Senior Project
 * Job Model
 * Defines the structure of a job posting stored in Firestore
 */

import 'package:cloud_firestore/cloud_firestore.dart';

//***********************************************************************************
// Contains all the information needed to display and manage a job
class JobModel {
  final String id;              // Unique job ID (generated from timestamp)
  final String userId;          // Firebase UID of the job poster
  final String userName;        // Display name of the job poster
  final String title;           // Brief job title ("I need someone to clean...")
  final String description;     // Detailed description of the job
  final double price;           // Amount the poster is willing to pay
  final List<String> imageUrls; // List of image paths (local or cloud URLs)
  final DateTime createdAt;     // When the job was posted
  final String status;          // Current status: 'open', 'in_progress', or 'completed'
  final String? acceptedById;   // Firebase UID of the user who accepted the job
  final String category;        // Job category for filtering (e.g., 'Cleaning', 'Tutoring', 'Delivery')

  JobModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    required this.description,
    required this.price,
    this.imageUrls = const [],   // Default to empty list if no images
    required this.createdAt,
    this.status = 'open',        // New jobs start with 'open' status
    this.acceptedById,           // Null until someone accepts the job
    this.category = 'Other',     // Default category if not specified
  });

  //*********************************************************************************
  // Converts JobModel object to a Map format that Firestore can store
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'title': title,
      'description': description,
      'price': price,
      'imageUrls': imageUrls,
      'createdAt': createdAt.toIso8601String(), // Convert DateTime to string for storage
      'status': status,
      'acceptedById': acceptedById,
      'category': category,
    };
  }

  //*********************************************************************************
  // Factory constructor that creates a JobModel from a Firestore Map
  factory JobModel.fromMap(Map<String, dynamic> map) {
    // Handle createdAt - can be Timestamp or legacy string
    DateTime createdAtDate;
    if (map['createdAt'] is Timestamp) {
      createdAtDate = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      createdAtDate = DateTime.parse(map['createdAt']); // Legacy string support
    } else {
      createdAtDate = DateTime.now();
    }

    return JobModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),              // Ensure value is a double
      imageUrls: List<String>.from(map['imageUrls'] ?? []), // Convert dynamic list to string list
      createdAt: createdAtDate,                              // Convert Timestamp or string to DateTime
      status: map['status'] ?? 'open',                      // Default to 'open' if missing
      acceptedById: map['acceptedById'],                    // Nullable, no default needed
      category: map['category'] ?? 'Other',                 // Default to 'Other' if missing
    );
  }

  //*********************************************************************************
  // Creates a new JobModel with optionally updated fields
  JobModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? title,
    String? description,
    double? price,
    List<String>? imageUrls,
    DateTime? createdAt,
    String? status,
    String? acceptedById,
    String? category,
  }) {
    return JobModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      acceptedById: acceptedById ?? this.acceptedById,
      category: category ?? this.category,
    );
  }
}

//116 lines of code on this file