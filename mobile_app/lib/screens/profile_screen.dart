/*
 * Samuel Bulnes
 * Senior Project
 * Profile Screen
 * Displays user information and job history
 */

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
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

  // Stores the currently authenticated user's information
  UserModel? _currentUser;

  // Used to control loading state while fetching user data
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Load user data as soon as the screen initializes
    _loadUserData();
  }

  //***********************************************************************************
  // LOAD USER DATA FROM FIRESTORE
  // Fetches user data from Firestore through AuthService
  Future<void> _loadUserData() async {
    final userData = await _authService.getCurrentUserData();

    // Update UI with retrieved user info
    setState(() {
      _currentUser = userData;
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
      return const Scaffold(
        body: Center(child: Text('Error loading user data')),
      );
    }

  //App Bar
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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

                  // Static 5-star rating (placeholder for future dynamic rating)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            const SizedBox(height: 24),

            //Job History Section
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingLarge,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title: Completed Jobs
                  const Text(
                    'Jobs completed', // Spanish label kept intentionally
                    // Equivalent in English: "Completed Jobs"
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Placeholder job history items
                  _buildJobItem('Samuel Bulnes', 'I need to clean my room'),
                  _buildJobItem('Gabriela Ballesteros', 'I need help to move heavy stuff'),
                  _buildJobItem('Tyler Smith', 'I need someone to pick up ...'),

                  const SizedBox(height: 32),

                  // Title: Requests Done
                  const Text(
                    'Jobs requested', // "Requests Made"
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // More placeholder job items
                  _buildJobItem('Shostin Rodriguez', 'I need to clean my room'),
                  _buildJobItem('Shostin Rodriguez', 'I need help to move heavy stuff'),
                  _buildJobItem('Shostin Rodriguez', 'I need someone to pick up ...'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //*************************************************************************************
  // Builds a job/request card item displaying:
  // - User avatar
  // - User name
  // - Description of the task
  // - Static 5-star rating
  Widget _buildJobItem(String userName, String description) {
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
          // Avatar using first letter of user's name
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: Text(
              userName[0],
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),

          // Job details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username
                Text(
                  userName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                // Job description
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Static rating (placeholder for database value)
          const Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 16),
              Icon(Icons.star, color: Colors.amber, size: 16),
              Icon(Icons.star, color: Colors.amber, size: 16),
              Icon(Icons.star, color: Colors.amber, size: 16),
              Icon(Icons.star, color: Colors.amber, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}


