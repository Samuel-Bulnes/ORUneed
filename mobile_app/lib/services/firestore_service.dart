/*
 * Samuel Bulnes
 * Senior Project
 * Firestore Service
 * Firestore operations for jobs and users
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/job_model.dart';
import '../models/user_model.dart';

//***********************************************************************************
// Firestore service that handles all job-related database operations
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //***********************************************************************************
  // Get all open jobs
  // Returns jobs with status='open', ordered by newest first
  // Handles both new jobs (with status field) and legacy jobs (without status)
  Stream<List<JobModel>> getOpenJobs() {
    return _firestore
        .collection('jobs')
        .orderBy('createdAt', descending: true)  // Sort at Firestore level
        .snapshots()
        .map((snapshot) {
      // Convert every Firestore document to JobModel and filter in memory
      return snapshot.docs
          .map((doc) => JobModel.fromMap(doc.data()))
          .where((job) => job.status == 'open')  // Filter in memory (handles missing status field)
          .toList();
    });
  }

  //***********************************************************************************
  // Get first page of open jobs (pagination)
  // Loads initial 20 jobs, returns jobs + last document for cursor-based pagination
  Future<Map<String, dynamic>> getOpenJobsFirstPage({int pageSize = 20}) async {
    try {
      final query = await _firestore
          .collection('jobs')
          .orderBy('createdAt', descending: true)
          .limit(pageSize)
          .get();

      // Convert documents to JobModel and filter in memory for open jobs
      final jobs = query.docs
          .map((doc) => JobModel.fromMap(doc.data()))
          .where((job) => job.status == 'open')  // Filter in memory (handles missing status field)
          .toList();

      // Return jobs and last document for next page cursor
      return {
        'jobs': jobs,
        'lastDocument': query.docs.isNotEmpty ? query.docs.last : null,
        'hasMore': query.docs.length == pageSize,
      };
    } catch (e) {
      print('Error getting first page: $e');
      rethrow;
    }
  }

  //***********************************************************************************
  // Get next page of open jobs (pagination)
  // Loads next 20 jobs using cursor-based pagination (startAfterDocument)
  Future<Map<String, dynamic>> getOpenJobsNextPage(
    DocumentSnapshot lastDocument, {
    int pageSize = 20,    
  }) async {
    try { // Ensure lastDocument is provided for pagination
      final query = await _firestore
          .collection('jobs')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastDocument)
          .limit(pageSize)
          .get();

      // Convert documents to JobModel and filter in memory for open jobs
      final jobs = query.docs
          .map((doc) => JobModel.fromMap(doc.data()))
          .where((job) => job.status == 'open')  // Filter in memory (handles missing status field)
          .toList();

      // Return jobs and last document for next page cursor
      return {
        'jobs': jobs,
        'lastDocument': query.docs.isNotEmpty ? query.docs.last : null,
        'hasMore': query.docs.length == pageSize,
      };
    } catch (e) {
      print('Error getting next page: $e');
      rethrow;
    }
  }

  //***********************************************************************************
  // Get jobs created by a specific user
  // Used for "My Jobs" section (jobs posted by logged-in user)
  Stream<List<JobModel>> getUserJobs(String userId) {
    return _firestore
        .collection('jobs')
        .where('userId', isEqualTo: userId) // Filter by job poster
        .snapshots()
        .map((snapshot) {
      final jobs = snapshot.docs
          .map((doc) => JobModel.fromMap(doc.data()))
          .toList();

      // Sort by creation time descending
      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return jobs;
    });
  }

  //***********************************************************************************
  // Gets jobs accepted by a user
  // Used for "My Accepted Jobs" or "Jobs I'm Working On" section
  Stream<List<JobModel>> getAcceptedJobs(String userId) {
    return _firestore
        .collection('jobs')
        .where('acceptedById', isEqualTo: userId) // Filter by acceptor
        .snapshots()
        .map((snapshot) {
      final jobs = snapshot.docs
          .map((doc) => JobModel.fromMap(doc.data()))
          .toList();

      // Sort by creation time: newest first
      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return jobs;
    });
  }

  //***********************************************************************************
  // Create new job
  // Writes a new job document using a pre-generated ID from JobModel
  Future<void> createJob(JobModel job) async {
    try {
      // Write job document using the job's ID as the document ID
      await _firestore.collection('jobs').doc(job.id).set(job.toMap());
      print('Job created: ${job.title}');
    } catch (e) {
      print('Error creating job: $e');
      rethrow; // Pass error back to UI
    }
  }

  //***********************************************************************************
  // Update existing Job
  // Updates specific fields of a job without replacing the entire document
  Future<void> updateJob(String jobId, Map<String, dynamic> updates) async {
    try {
      // Update only the specified fields
      await _firestore.collection('jobs').doc(jobId).update(updates);
      print('Job updated: $jobId');
    } catch (e) {
      print('Error updating job: $e');
      rethrow;
    }
  }

  //***********************************************************************************
  // Accept a job
  // Sets status to "in_progress" and assigns job to the user
  // Called when someone accepts a posted job=
  Future<void> acceptJob(String jobId, String userId) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update({
        'status': 'in_progress', // Mark job as being worked on
        'acceptedById': userId, // Record who accepted it
      });
      print('Job accepted: $jobId');
    } catch (e) {
      print('Error accepting job: $e');
      rethrow;
    }
  }

  //***********************************************************************************
  // Complete Job
  // Sets status to "completed"
  Future<void> completeJob(String jobId) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update({
        'status': 'completed', // Mark job as finished
      });
      print('Job completed: $jobId');
    } catch (e) {
      print('Error completing job: $e');
      rethrow;
    }
  }

  //***********************************************************************************
  // Get completed or in-progress jobs (user's history)
  // Returns jobs the user has accepted (acceptedById) or posted (userId)
  // with status 'in_progress' or 'completed'
  Stream<List<JobModel>> getUserHistory(String userId) {
    return _firestore
        .collection('jobs')
        .snapshots()
        .map((snapshot) {
      // Get all jobs where user is either the poster or acceptor
      final userJobs = snapshot.docs
          .map((doc) => JobModel.fromMap(doc.data()))
          .where((job) =>
              (job.userId == userId || job.acceptedById == userId) &&
              (job.status == 'in_progress' || job.status == 'completed'))
          .toList();

      // Sort by creation time: newest first
      userJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return userJobs;
    });
  }

  //***********************************************************************************
  // Get Job by ID
  // Fetches job document only once (not a stream)
  Future<JobModel?> getJob(String jobId) async {
    try {
      // Get job document by ID
      DocumentSnapshot doc =
          await _firestore.collection('jobs').doc(jobId).get();

      // Check if document exists
      if (!doc.exists) return null;

      // Convert Firestore document to JobModel object
      return JobModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('Error getting job: $e');
      return null;
    }
  }

  //***********************************************************************************
  // Delete Job
  // Removes the job document from Firestore
  Future<void> deleteJob(String jobId) async {
    try {
      await _firestore.collection('jobs').doc(jobId).delete();
      print('Job deleted: $jobId');
    } catch (e) {
      print('Error deleting job: $e');
      rethrow;
    }
  }

  //***********************************************************************************
  // Get User by ID
  // Fetches user document only once (not a stream)
  Future<UserModel?> getUser(String userId) async {
    try {
      // Get user document by ID
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(userId).get();

      // Check if document exists
      if (!doc.exists) return null;

      // Convert Firestore document to UserModel object
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }
}
// 274 Lines of code in this file