/*
 * Samuel Bulnes
 * Senior Project
 * Job Filter Provider
 * State management for job filtering and sorting
 */

import 'package:flutter/material.dart';

//***********************************************************************************
// List of available job categories for filtering
class JobCategories {
  static const List<String> categories = [
    'All',
    'Cleaning',
    'Tutoring',
    'Delivery',
    'Handyman',
    'Gardening',
    'Pet Care',
    'Tech Support',
    'Writing',
    'Design',
    'Other',
  ];

  // Map of category names to icons for UI display
  static const Map<String, IconData> categoryIcons = {
    'All': Icons.apps,
    'Cleaning': Icons.cleaning_services,
    'Tutoring': Icons.school,
    'Delivery': Icons.local_shipping,
    'Handyman': Icons.handyman,
    'Gardening': Icons.nature,
    'Pet Care': Icons.pets,
    'Tech Support': Icons.computer,
    'Writing': Icons.edit,
    'Design': Icons.palette,
    'Other': Icons.work,
  };
}

//***********************************************************************************
// Provider for managing job filters and search state
class JobFilterProvider extends ChangeNotifier {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  // Getters
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get hasActiveFilters => _selectedCategory != 'All' || _searchQuery.isNotEmpty;

  //***********************************************************************************
  // Update selected category and notify listeners
  void setCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  //***********************************************************************************
  // Update search query and notify listeners
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  //***********************************************************************************
  // Reset all filters to default state
  void resetFilters() {
    _selectedCategory = 'All';
    _searchQuery = '';
    notifyListeners();
  }

  //***********************************************************************************
  // Check if a job matches current filters
  bool matchesFilters({
    required String jobCategory,
    required String jobTitle,
    required String jobDescription,
  }) {
    // Check category filter
    if (_selectedCategory != 'All' && jobCategory != _selectedCategory) {
      return false;
    }

    // Check search query filter (searches in title and description)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      final titleMatch = jobTitle.toLowerCase().contains(query);
      final descriptionMatch = jobDescription.toLowerCase().contains(query);
      if (!titleMatch && !descriptionMatch) {
        return false;
      }
    }

    return true;
  }
}

//104 lines of code on this file