/*
 * Samuel Bulnes
 * Senior Project
 * Main file
 * Everything starts from here.
*/

import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import 'dart:io';

//***********************************************************************************
/* 
*  A reusable card widget that displays job information in the feed
*  Shows job title, description, price, user info, and images
*  Used in the home screen to display all available jobs
*/
class JobCard extends StatelessWidget {
  final JobModel job; // The job data to display in this card
  final VoidCallback onTap;

  // Callback function executed when user taps the card
  // Used to navigate to job details screen
  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
  });

  //*********************************************************************************
  @override
  Widget build(BuildContext context) {
    return Card(
      // Add spacing around the card
      margin: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingMedium,
        vertical: AppSizes.paddingSmall,
      ),

      elevation: AppSizes.cardElevation, // Card shadow depth

      // Rounded corners for the card
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),

      // InkWell adds ripple tap animation to Card
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),

        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              //********************************************************************
              // HEADER SECTION
              // Displays user avatar, name, post time, and price
              Row(
                children: [
                  // User Initial (Avatar)
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Text(
                      job.userName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Username + Relative time ("5m ago")
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display user's full name
                        Text(
                          job.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        // Display how long ago the job was posted
                        Text(
                          _formatDate(job.createdAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Price badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '\$${job.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              //********************************************************************
              // JOB TITLE
              Text(
                job.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2, // Limit to 2 lines
                overflow: TextOverflow.ellipsis,// Add "..." if text is too long
              ),

              const SizedBox(height: 8),

              //********************************************************************
              // JOB DESCRIPTION (short preview)
              Text(
                job.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                maxLines: 3, // Limit to 3 lines
                overflow: TextOverflow.ellipsis, // Add "..." if text is too long
              ),

              //********************************************************************
              // JOB IMAGES
              // Only show if the job has images
              // Only displayed if job.imageUrls is not empty
              if (job.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),

                // Horizontal scrollable list of images
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,

                    // Show maximum 3 images
                    itemCount:
                        job.imageUrls.length > 3 ? 3 : job.imageUrls.length,
                    itemBuilder: (context, index) {
                      final imagePath = job.imageUrls[index];

                      return Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),

                        // Rounded corners for images
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),

                          // If stored using "local:<path>", load from file
                          child: imagePath.startsWith('local:')
                              ? Image.file(
                                  File(
                                      imagePath.replaceFirst('local:', '')),
                                  fit: BoxFit.cover,

                                  // Show placeholder icon if image fails to load
                                  errorBuilder: (context, error, stackTrace) {

                                    // Fallback UI if loading fails
                                    return const Center(
                                      child:
                                          Icon(Icons.image, color: Colors.grey),
                                    );
                                  },
                                )

                              // Placeholder for future Firestore/Cloud images
                              : const Center(
                                  child:
                                      Icon(Icons.image, color: Colors.grey),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  //*********************************************************************************
  /* 
  *  FORMAT RELATIVE DATE
  *  Converts timestamp into human-readable short format.
  *   - "Just now" (less than 1 minute ago)
  *   - "5m ago" (minutes)
  *   - "2h ago" (hours)
  *   - "3d ago" (days)
  *   - "Nov 20" (older than a week)
  */

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // Format as: "Jan 5"
      return DateFormat('MMM d').format(date);
    }
  }
}
