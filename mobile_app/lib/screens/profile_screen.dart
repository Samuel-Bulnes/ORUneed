/*
 * Samuel Bulnes
 * Senior Project
 * Profile Screen
 * Displays user information and job history
 */

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

//*************************************************************************************
// Profile screen that displays user information and activity
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Authentication service to handle user session and data retrieval
  final _authService = AuthService();
  final _chatService = ChatService();

  // Stores the currently authenticated user's information
  UserModel? _currentUser;

  // Used to control loading state while fetching user data
  bool _isLoading = true;

  // Stores worker ratings/reviews from completed jobs
  List<Map<String, dynamic>> _ratings = [];

  @override
  void initState() {
    super.initState();
    // Load user data as soon as the screen initializes
    _loadUserData();
  }

  //***********************************************************************************
  // LOAD USER DATA FROM FIRESTORE
  // Fetches user data from Firestore through AuthService
  // Optimized: Runs both queries in parallel for faster load time
  Future<void> _loadUserData() async {
    final userData = await _authService.getCurrentUserData();
    
    // Execute both queries in parallel using Future.wait
    final results = await Future.wait([
      _chatService.getWorkerRatings(userData?.uid ?? ''),
    ]);
    
    final ratings = results[0] as List<Map<String, dynamic>>;

    // Update UI with retrieved user info and ratings
    setState(() {
      _currentUser = userData;
      _ratings = ratings;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while fetching data
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Safety check in case user data fails to load
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.appName),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.neonBlue,
          centerTitle: true,
          actions: [
            // Logout button (clears session and redirects to login)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await _authService.signOut();

                // Prevents navigation issues if widget is unmounted
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Error loading user data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Your account data may have been reset.\nPlease log out and sign in again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

  //App Bar
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.neonBlue,
        centerTitle: true,
        actions: [
          // Logout button (clears session and redirects to login)
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();

              // Prevents navigation issues if widget is unmounted
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),

      // Allows scrolling in case content exceeds screen height
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header Section 
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.paddingLarge),
              color: AppColors.background,
              child: Column(
                children: [
                  // User avatar using first letter of their name
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      _currentUser!.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User full name
                  Text(
                    _currentUser!.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Dynamic rating based on worker reviews
                  _buildAverageRating(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            const SizedBox(height: 24),

            //Reviews Section
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingLarge,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title: Worker Reviews
                  const Text(
                    'Reviews received',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Show reviews or empty state
                  if (_ratings.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No reviews yet. Complete jobs to receive reviews!',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    ..._ratings.map((rating) => _buildReviewItem(rating)).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //*************************************************************************************
  // Builds the average rating display
  Widget _buildAverageRating() {
    if (_ratings.isEmpty) {
      return const Text(
        'No rating yet',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      );
    }

    // Calculate average rating
    double avg = _ratings.fold<double>(0, (sum, r) => sum + (r['rating'] as int)) /
        _ratings.length;

    // Build stars based on average
    int fullStars = avg.toInt();
    bool hasHalfStar = (avg - fullStars) >= 0.5;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Full stars
        ...List.generate(
          fullStars,
          (index) => const Icon(Icons.star, color: Colors.amber, size: 20),
        ),
        // Half star if needed
        if (hasHalfStar)
          const Icon(Icons.star_half, color: Colors.amber, size: 20),
        // Empty stars
        ...List.generate(
          5 - fullStars - (hasHalfStar ? 1 : 0),
          (index) => const Icon(Icons.star_outline, color: Colors.amber, size: 20),
        ),
        const SizedBox(width: 8),
        Text(
          '${avg.toStringAsFixed(1)} (${_ratings.length})',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  //*************************************************************************************
  // Builds a review card showing rating, reviewer name, and date
  Widget _buildReviewItem(Map<String, dynamic> review) {
    final rating = review['rating'] as int;
    final raterName = review['raterName'] as String;
    final completedAt = review['completedAt'] as DateTime?;

    // Format date
    String dateStr = 'Recently';
    if (completedAt != null) {
      dateStr = '${completedAt.month}/${completedAt.day}/${completedAt.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // Avatar using first letter of reviewer's name
          CircleAvatar(
            backgroundColor: AppColors.primary,
            radius: 20,
            child: Text(
              raterName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Review details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reviewer name
                Text(
                  raterName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                // Date
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Rating stars
          Row(
            children: List.generate(
              rating,
              (index) => const Icon(Icons.star, color: Colors.amber, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}


