/*
 * Samuel Bulnes
 * Senior Project
 * Rating Model
 * Defines the structure of a rating given by a poster to a worker
 */

import 'package:cloud_firestore/cloud_firestore.dart';

//***********************************************************************************
// Stores rating information for completed jobs
// Each rating is a separate document in a subcollection under chats
class Rating {
  final String id;              // Rating document ID (auto-generated)
  final String chatId;          // Reference to the chat where work was completed
  final String workerId;        // User ID of the worker who received the rating
  final String posterId;        // User ID of the poster who gave the rating
  final int rating;             // Rating value (1-5 stars)
  final String jobId;           // Reference to the job that was completed
  final DateTime createdAt;     // When the rating was given

  Rating({
    required this.id,
    required this.chatId,
    required this.workerId,
    required this.posterId,
    required this.rating,
    required this.jobId,
    required this.createdAt,
  });

  //***********************************************************************************
  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'workerId': workerId,
      'posterId': posterId,
      'rating': rating,
      'jobId': jobId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  //***********************************************************************************
  // Create from Firestore
  factory Rating.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    DateTime createdAt;
    try {
      final timestampData = data['createdAt'];
      if (timestampData != null && timestampData is Timestamp) {
        createdAt = timestampData.toDate();
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      createdAt = DateTime.now();
    }

    return Rating(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      workerId: data['workerId'] ?? '',
      posterId: data['posterId'] ?? '',
      rating: data['rating'] ?? 0,
      jobId: data['jobId'] ?? '',
      createdAt: createdAt,
    );
  }
}

//73 lines of code on this file