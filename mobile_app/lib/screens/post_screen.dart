/*
 * Samuel Bulnes
 * Senior Project
 * Post Screen
 * Job creation interface with image upload and price calculation
 */

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/job_model.dart';
import '../providers/job_filter_provider.dart';
import '../utils/constants.dart';

//*************************************************************************************
// Job posting screen where users can create new job listings
// Allows users to add title, description, images, and price for services
class PostScreen extends StatefulWidget {
  final VoidCallback? onJobPosted;
  
  const PostScreen({super.key, this.onJobPosted});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

//*****************************************************************************************
// Main state for the post screen, handling form input, image selection, and job submission
class _PostScreenState extends State<PostScreen> {
  // Form validation key
  final _formKey = GlobalKey<FormState>();
  
  // Text controllers for job details
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  
  // Service instances for authentication and database operations
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _imagePicker = ImagePicker();
  
  // UI state variables
  bool _isLoading = false;
  List<File> _selectedImages = [];
  String _selectedCategory = 'Other';

  @override
  void dispose() {
    // Clean up text controllers to prevent memory leaks
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // Opens gallery to select multiple images
  // Limited to maximum of 4 images with 70% compression quality
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 70, // Compress images to reduce file size
      );

      // Enforce 4 image maximum limit
      if (images.length > 4) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 4 images allowed'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Convert XFile to File and update state
      setState(() {
        _selectedImages = images.map((image) => File(image.path)).toList();
      });
    } catch (e) {
      print('Error picking images: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  //***********************************************************************************
  // Opens camera to take a new photo
  // Adds photo to existing selection if under 4 image limit
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70, // Compress image to reduce file size
      );

      if (photo == null) return; // User cancelled

      // Check if maximum image limit reached
      if (_selectedImages.length >= 4) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 4 images allowed'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Add new photo to selection
      setState(() {
        _selectedImages.add(File(photo.path));
      });
    } catch (e) {
      print('Error taking photo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error taking photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  //***********************************************************************************
  // Removes image from selection at specified index
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  //***********************************************************************************
  // Handles job submission process
  // Validates form, creates job model, saves to Firestore, and shows confirmation
  Future<void> _handleSubmit() async {
    // Validate all form fields
    if (!_formKey.currentState!.validate()) return;

    // Ask for confirmation before publishing
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Publish job', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to publish this job?', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.neonBlue)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Publish',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.neonBlue),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      // Get current user information
      final currentUser = _authService.currentUser;
      final userData = await _authService.getCurrentUserData();

      if (currentUser == null || userData == null) {
        throw Exception('User not found');
      }

      // Generate unique job ID using timestamp
      final jobId = DateTime.now().millisecondsSinceEpoch.toString();

      // Store images as local paths with 'local:' prefix
      // In production, these would be uploaded to Firebase Storage
      final imageUrls = _selectedImages
          .map((img) => 'local:${img.path}')
          .toList();

      // Create job model with all details
      final job = JobModel(
        id: jobId,
        userId: currentUser.uid,
        userName: userData.name,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        imageUrls: imageUrls,
        createdAt: DateTime.now(),
        category: _selectedCategory,
      );

      // Save job to Firestore
      await _firestoreService.createJob(job);

      if (!mounted) return;

      // Clear all form fields after successful submission
      _titleController.clear();
      _descriptionController.clear();
      _priceController.clear();
      setState(() {
        _selectedImages.clear();
      });

      // Call callback to navigate back to home page and show the newly posted job
      if (widget.onJobPosted != null) {
        widget.onJobPosted!();
      }


    } catch (e) {
      if (!mounted) return;

      // Show error message if submission fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Hide loading indicator
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ORUneed'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.neonBlue,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page header
              const Text(
                'What do you need?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              //***********************************************************************************
              //  Job title input field
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'I need ...',
                  hintStyle: const TextStyle(color: Color(0xFF666666)),
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
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: const BorderSide(color: Colors.red, width: 1),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              //***********************************************************************************
              // Job description section
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              // Description field
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'It\'s a ...',
                  hintStyle: const TextStyle(color: Color(0xFF666666)),
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
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: const BorderSide(color: Colors.red, width: 1),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
                maxLines: 6,
              ),
              const SizedBox(height: 16),

              //***********************************************************************************
              // Image selection section
              const Text(
                'Add images',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),

              // Grid displaying selected images with remove option
              if (_selectedImages.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        // Display image thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                          child: Image.file(
                            _selectedImages[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        // Remove button overlay
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            onPressed: () => _removeImage(index),
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(4),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              
              const SizedBox(height: 8),

              //***********************************************************************************
              // Image selection buttons (Gallery and Camera)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.photo_library, color: AppColors.neonBlue),
                      label: const Text('Gallery', style: TextStyle(color: AppColors.neonBlue)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF444444), width: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt, color: AppColors.neonBlue),
                      label: const Text('Camera', style: TextStyle(color: AppColors.neonBlue)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF444444), width: 1),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Image count indicator
              if (_selectedImages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${_selectedImages.length}/4 images selected',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              //***********************************************************************************
              // Category selection section
              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                style: const TextStyle(color: AppColors.textPrimary),
                dropdownColor: AppColors.cardBackground,
                decoration: InputDecoration(
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
                items: JobCategories.categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Price input section
              const Text(
                'How much you will pay?',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              // Price field
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: const TextStyle(color: AppColors.neonBlue),
                  hintText: '20.00',
                  hintStyle: const TextStyle(color: Color(0xFF666666)),
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
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: const BorderSide(color: Colors.red, width: 1),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              const SizedBox(height: 32),

              //***********************************************************************************
              //  Submit button with loading state
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Publish',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// 591 lines of code in this file