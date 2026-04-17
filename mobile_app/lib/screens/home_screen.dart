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
  
  // Pagination state
  List<JobModel> _paginatedJobs = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMoreJobs = true;
  late ScrollController _scrollController;
  bool _isInitialLoadDone = false;

  @override
  void initState() {
    super.initState();
    _filterProvider = JobFilterProvider();
    _searchController.addListener(() {
      _filterProvider.setSearchQuery(_searchController.text);
    });
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadUserData();
    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  //***********************************************************************************
  // Load first page of jobs
  Future<void> _loadFirstPage() async {
    try {
      final result = await _firestoreService.getOpenJobsFirstPage();
      setState(() {
        _paginatedJobs = List<JobModel>.from(result['jobs']);
        _lastDocument = result['lastDocument'];
        _hasMoreJobs = result['hasMore'];
        _isInitialLoadDone = true;
      });
    } catch (e) {
      print('Error loading first page: $e');
      setState(() {
        _isInitialLoadDone = true;
      });
    }
  }

  //***********************************************************************************
  // Load more jobs when user scrolls to bottom
  Future<void> _loadMoreJobs() async {
    if (_isLoadingMore || !_hasMoreJobs || _lastDocument == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final result = await _firestoreService.getOpenJobsNextPage(_lastDocument!);
      setState(() {
        _paginatedJobs.addAll(List<JobModel>.from(result['jobs']));
        _lastDocument = result['lastDocument'];
        _hasMoreJobs = result['hasMore'];
        _isLoadingMore = false;
      });
    } catch (e) {
      print('Error loading more jobs: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  //***********************************************************************************
  // Detect scroll position and load more when near bottom
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreJobs();
    }
  }

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
            decoration: InputDecoration(
              hintText: 'Search jobs...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                borderSide: const BorderSide(color: Colors.grey, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                borderSide: const BorderSide(color: Colors.grey, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
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
                  backgroundColor: Colors.grey[200],
                  selectedColor: AppColors.primary.withOpacity(0.8),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
  // Builds the filtered jobs list with pagination
  // Shows loading spinner initially, then loads jobs with infinite scroll
  Widget _buildJobsList() {
    // Show loading spinner on initial load
    if (!_isInitialLoadDone) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter jobs based on category and search query
    final filteredJobs = _paginatedJobs.where((job) {
      return _filterProvider.matchesFilters(
        jobCategory: job.category,
        jobTitle: job.title,
        jobDescription: job.description,
      );
    }).toList();

    // Show empty state if no jobs found
    if (filteredJobs.isEmpty && _paginatedJobs.isEmpty) {
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
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedIndex = 1;
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

    // Show no results state if filters don't match
    if (filteredJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No jobs found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            if (_filterProvider.hasActiveFilters)
              GestureDetector(
                onTap: () {
                  _filterProvider.resetFilters();
                  _searchController.clear();
                  setState(() {});
                },
                child: Text(
                  'Clear filters',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Display filtered jobs with infinite scroll
    return RefreshIndicator(
      onRefresh: () async {
        _scrollController.jumpTo(0);
        await _loadFirstPage();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: filteredJobs.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at bottom when loading more
          if (index == filteredJobs.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
            );
          }

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
  }
}