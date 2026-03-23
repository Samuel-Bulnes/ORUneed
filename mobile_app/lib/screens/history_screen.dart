/*
 * Samuel Bulnes
 * Senior Project
 * History Screen
 * Displays user's completed job history with ratings and earnings
 */

import 'package:flutter/material.dart';
import '../utils/constants.dart';

//*************************************************************************************
// Screen that displays the user's job history
// Shows completed jobs with ratings and earnings
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSizes.paddingMedium),

        // Replace with actual data from database
        itemCount: 3, // Placeholder count
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              //**********************************************************************
              // User avatar with first letter
              leading: CircleAvatar(
                backgroundColor: AppColors.primary,
                child: const Text('U', style: TextStyle(color: Colors.white)),
              ),

              //**********************************************************************
              // Job description
              title: const Text(
                'I need someone that can clean my room',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              //**********************************************************************
              // Completion date
              subtitle: const Text('Completed on Wednesday'),

              //**********************************************************************
              // Price and rating display
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  //*****************************************************************
                  // Job payment amount
                  const Text(
                    '\$10',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  //*****************************************************************
                  // 5-star rating display
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (i) => const Icon(Icons.star, size: 12, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}