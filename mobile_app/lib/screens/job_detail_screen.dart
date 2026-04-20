/*
 * Samuel Bulnes
 * Senior Project
 * Job Detail Screen
 * Displays complete job information with accept and message actions
 */

import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/chat_service.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'chat_screen.dart';

//*************************************************************************************
// Job detail screen that displays complete information about a specific job
// Allows users to accept jobs, message the job poster, and view job status
class JobDetailScreen extends StatelessWidget {
  final JobModel job;

  const JobDetailScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    // Initialize services for authentication, database, and chat operations
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final chatService = ChatService();
    
    // Get current user information
    final currentUserId = authService.currentUser?.uid;
    final currentUserName = authService.currentUser?.displayName ?? 'Unknown';
    
    // Check if current user is the job owner
    final isOwnJob = currentUserId == job.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ORUneed'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.neonBlue,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user avatar
            Container(
              width: double.infinity,
              height: 200,
              color: AppColors.cardBackground,
              child: Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.neonBlue,
                  // Display first letter of username as avatar
                  child: Text(
                    job.userName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // User information and job details section
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User name and post timestamp
                  Center(
                    child: Column(
                      children: [
                        Text(
                          job.userName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Format creation date in readable format
                        Text(
                          DateFormat('MMMM d, yyyy • h:mm a').format(job.createdAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Job title and description card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          job.description,
                          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image gallery - horizontal scrollable list of job images
                  if (job.imageUrls.isNotEmpty)
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: job.imageUrls.length,
                        itemBuilder: (context, index) {
                          final imagePath = job.imageUrls[index];

                          return Container(
                            width: 150,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                              // Handle local file paths (offline images)
                              child: imagePath.startsWith('local:')
                                  ? Image.file(
                                      File(imagePath.replaceFirst('local:', '')),
                                      fit: BoxFit.cover,
                                      // Show fallback icon if image fails to load
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Center(
                                          child: Icon(Icons.image, size: 50, color: Colors.grey),
                                        );
                                      },
                                    )
                                  : const Center(
                                      child: Icon(Icons.image, size: 50, color: Colors.grey),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Price display - prominently shown in center
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neonBlue,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                          '\$${job.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Action buttons (only shown if not own job and job is open)
                  if (!isOwnJob && job.status == 'open')
                    Row(
                      children: [
                        // Accept button - commits user to take the job
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              try {
                                // Update job status in Firestore
                                await firestoreService.acceptJob(job.id, currentUserId!);

                                if (!context.mounted) return;

                                // Open chat immediately after accepting job

                                await _createChat(
                                  context,
                                  chatService,
                                  currentUserId,
                                  currentUserName,
                                );
                              } catch (e) {
                                // Handle errors (e.g., network issues, permission errors)
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.neonBlue, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text(
                              'Accept',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.neonBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Message button - opens chat with job poster
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _createChat(
                              context,
                              chatService,
                              currentUserId!,
                              currentUserName,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.neonBlue, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              color: AppColors.neonBlue,
                              size: 20,
                            ),
                            label: const Text(
                              'Message',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.neonBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Info banner for job owners - shown when viewing own job
                  if (isOwnJob && job.status == 'open')
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.neonBlue),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.neonBlue),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'This is your post. Wait for someone to accept it!',
                              style: TextStyle(color: AppColors.neonBlue),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Status banner for jobs in progress or completed
                  if (job.status != 'open')
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: job.status == 'completed' ? Colors.green : Colors.orange,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            job.status == 'completed'
                                ? Icons.check_circle
                                : Icons.hourglass_empty,
                            color: job.status == 'completed'
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              job.status == 'completed'
                                  ? 'This job is completed'
                                  : 'This job is in progress',
                              style: TextStyle(
                                color: job.status == 'completed'
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //*************************************************************************************
  // Creates or retrieves existing chat between current user and job poster
  // Handles validation and navigation to chat screen
  Future<void> _createChat(
    BuildContext context,
    ChatService chatService,
    String currentUserId,
    String currentUserName,
  ) async {
    // Validate user is logged in
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ You must be logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Prevent user from messaging themselves
    if (currentUserId == job.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ You cannot message yourself'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Show loading indicator while creating/fetching chat
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );

      // Get existing chat or create new one if it doesn't exist
      final chatId = await chatService.getOrCreateChat(
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        otherUserId: job.userId,
        otherUserName: job.userName,
        jobId: job.id,
        jobTitle: job.title,
        workerId: currentUserId, // The person who accepts = the worker
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);

        // Navigate to chat screen with job context
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              otherUserId: job.userId,
              otherUserName: job.userName,
              jobId: job.id,
              jobTitle: job.title,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog on error
      if (context.mounted) {
        Navigator.pop(context);

        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}