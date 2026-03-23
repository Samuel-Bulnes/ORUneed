/*
 * Samuel Bulnes
 * Senior Project
 * Home Screen
 * Main navigation hub with bottom navigation bar and job feed display
 */

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/job_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import '../job_card.dart';
import 'job_detail_screen.dart';
import 'post_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'chat_list_screen.dart';

//*************************************************************************************
// Main home screen widget with bottom navigation
// Manages the main app navigation and displays available jobs
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

//*************************************************************************************
// Main home screen widget with bottom navigation
class _HomeScreenState extends State<HomeScreen> {
  // Services for authentication and database operations
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  
  // Current selected index for bottom navigation bar
  int _selectedIndex = 0;
  
  // Current logged-in user data
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Loads current user data from authentication service
  Future<void> _loadUserData() async {
    final userData = await _authService.getCurrentUserData();
    setState(() {
      _currentUser = userData;
    });
  }

  // Handles bottom navigation bar item tap events
  // Updates the selected index to switch between screens
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Bottom navigation pages list
    final List<Widget> pages = [
      _buildHomePage(),      // Search/Jobs feed
      const PostScreen(),    // Create new job post
      const ProfileScreen(), // User profile
      const HistoryScreen(), // Job history
      const ChatListScreen(), // Messages
    ];

    return Scaffold(
      // Show app bar only on home page (index 0)
      appBar: _selectedIndex == 0
          ? AppBar(
              title: const Text(AppStrings.appName),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              centerTitle: true,
            )
          : null,
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Publish',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
        ],
      ),
    );
  }

  //*************************************************************************************
  // Builds the home page with job listings
  // Uses StreamBuilder to listen for real-time updates from Firestore
  Widget _buildHomePage() {
    return StreamBuilder<List<JobModel>>(
      stream: _firestoreService.getOpenJobs(),
      builder: (context, snapshot) {
        // Loading state - show spinner while fetching data
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state - display error message with retry option
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Empty state - no jobs available yet
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.work_outline,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No jobs available yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to post!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 24),
                // Button to navigate to Post screen
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 1; // Navigate to Post tab
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Post'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Success state - display list of available jobs
        final jobs = snapshot.data!;

        return RefreshIndicator(
          // Pull-to-refresh functionality
          onRefresh: () async {
            setState(() {}); // Trigger rebuild to refresh stream
            await Future.delayed(const Duration(seconds: 1));
          },
          child: ListView.builder(
            // Add padding to avoid content being hidden behind bottom nav bar
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return JobCard(
                job: job,
                // Navigate to job details when card is tapped
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => JobDetailScreen(job: job),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}