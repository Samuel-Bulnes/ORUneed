/*
 * Samuel Bulnes
 * Senior Project
 * History Screen
 * Displays user's completed job history and in-progress jobs
 */

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/job_model.dart';
import '../utils/constants.dart';
import '../job_card.dart';
import 'job_detail_screen.dart';

//*************************************************************************************
// Screen that displays the user's job history
// Shows jobs user has accepted or posted that are in_progress or completed
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

//*************************************************************************************
// Main history screen state
class _HistoryScreenState extends State<HistoryScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    // Get current user ID
    final userId = _authService.currentUser?.uid;

    // If no user is logged in, show error
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ORUneed'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.neonBlue,
          centerTitle: true,
        ),
        body: const Center(
          child: Text('Please sign in to view history'),
        ),
      );
    }

    //**********************************************************************************
    // StreamBuilder to listen to user's job history in real-time
    return Scaffold(
      appBar: AppBar(
        title: const Text('ORUneed'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.neonBlue,
        centerTitle: true,
      ),
      body: StreamBuilder<List<JobModel>>(
        stream: _firestoreService.getUserHistory(userId),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonBlue,
                    ),
                    child: const Text('Retry', style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            );
          }

          // Empty state
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.history,
                    size: 80,
                    color: Color(0xFF666666),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No history yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Jobs you accept or post will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            );
          }

          // Success state -> display list of jobs
          final jobs = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await Future.delayed(const Duration(seconds: 1));
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return JobCard(
                  job: job,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JobDetailScreen(job: job),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
// 155 lines of code in this file