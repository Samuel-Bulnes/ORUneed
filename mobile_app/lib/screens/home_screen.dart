/*
 * Samuel Bulnes
 * Senior Project
 * Home Screen
 * Main navigation hub with bottom navigation bar and job feed display
 */

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/job_model.dart';
import '../providers/job_filter_provider.dart';
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
  
  // Job filter state
  late JobFilterProvider _filterProvider;
  final TextEditingController _searchController = TextEditingController();
  late ScrollController _scrollController;
  
  // Stream for real-time job updates
  Stream<List<JobModel>>? _jobsStream;

  @override
  void initState() {
    super.initState();
    _filterProvider = JobFilterProvider();
    _searchController.addListener(() {
      _filterProvider.setSearchQuery(_searchController.text);
    });
    _scrollController = ScrollController();
    _loadUserData();
    
    // Initialize stream for real-time job updates
    _jobsStream = _firestoreService.getOpenJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  //***********************************************************************************
  // Loads current user data from authentication service
  Future<void> _loadUserData() async {
    final userData = await _authService.getCurrentUserData();
    // User data loaded but not stored (UI doesn't need it currently)
    if (userData == null) {
      print('No user data found');
    }
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
      PostScreen(
        onJobPosted: () {
          // Navigate to home page (index 0) when a job is successfully posted
          setState(() {
            _selectedIndex = 0;
          });
        },
      ),    // Create new job post
      const ProfileScreen(), // User profile
      const HistoryScreen(), // Job history
      const ChatListScreen(), // Messages
    ];

    return Scaffold(
      // Show app bar only on home page (index 0)
      appBar: _selectedIndex == 0
          ? AppBar(
              title: const Text('ORUneed'),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.neonBlue,
              centerTitle: true,
            )
          : null,
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.cardBackground,
        selectedItemColor: AppColors.neonBlue,
        unselectedItemColor: const Color(0xFF666666),
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
  // Builds the home page with job listings and filtering
  // Uses StreamBuilder to listen for real-time updates from Firestore
  Widget _buildHomePage() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(AppSizes.paddingLarge),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search jobs...',
              hintStyle: const TextStyle(color: Color(0xFF666666)),
              prefixIcon: const Icon(Icons.search, color: AppColors.neonBlue),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.neonBlue),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                borderSide: const BorderSide(color: Color(0xFF444444)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                borderSide: const BorderSide(color: Color(0xFF444444)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                borderSide: const BorderSide(color: AppColors.neonBlue, width: 2),
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
        
        // Category filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingLarge),
          child: SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: JobCategories.categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = JobCategories.categories[index];
                final isSelected = _filterProvider.selectedCategory == category;
                
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        JobCategories.categoryIcons[category],
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(category),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _filterProvider.setCategory(category);
                    });
                  },
                  backgroundColor: AppColors.cardBackground,
                  selectedColor: AppColors.neonBlue.withOpacity(0.8),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: const BorderSide(
                    color: Color(0xFF444444),
                    width: 1,
                  ),
                );
              },
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Jobs list
        Expanded(
          child: _buildJobsList(),
        ),
      ],
    );
  }

  //*************************************************************************************
  // Builds the filtered jobs list with real-time updates
  // Uses StreamBuilder to listen for real-time changes from Firestore
  Widget _buildJobsList() {
    return StreamBuilder<List<JobModel>>(
      stream: _jobsStream,
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Handle error state
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        // Get jobs from stream
        final jobs = snapshot.data ?? [];

        // Filter jobs based on category and search query
        final filteredJobs = jobs.where((job) {
          return _filterProvider.matchesFilters(
            jobCategory: job.category,
            jobTitle: job.title,
            jobDescription: job.description,
          );
        }).toList();

        // Show empty state if no jobs found
        if (filteredJobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.work_outline,
                  size: 80,
                  color: const Color(0xFF666666),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No jobs available',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                if (jobs.isEmpty)
                  const Text(
                    'Be the first to post!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF888888),
                    ),
                  )
                else
                  const Text(
                    'No jobs found with these filters',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF888888),
                    ),
                  ),
                if (jobs.isNotEmpty && filteredJobs.isEmpty)
                  GestureDetector(
                    onTap: () {
                      _filterProvider.resetFilters();
                      _searchController.clear();
                      setState(() {});
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'Clear filters',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.neonBlue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                if (jobs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedIndex = 1;
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Post'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonBlue,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        // Display filtered jobs with real-time updates
        return RefreshIndicator(
          onRefresh: () async {
            _scrollController.jumpTo(0);
            // Stream will auto-refresh from Firestore
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: filteredJobs.length,
            itemBuilder: (context, index) {
              final job = filteredJobs[index];
              return JobCard(
                job: job,
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

// 395 lines of code in this file