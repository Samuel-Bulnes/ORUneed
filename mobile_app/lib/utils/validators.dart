/*
 * Samuel Bulnes
 * Senior Project
 * Validators
 * Contains helper functions to validate user input in forms
*/

//***********************************************************************************
// Contains helper functions to validate user input in forms used throughout the app for email, password, and name validation
class Validators {

  //*********************************************************************************
  // Validates that the email is from Oral Roberts University (@oru.edu)
  static String? validateOruEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    
    // Check if email format is valid using regular expression
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    
    // Check if email domain is specifically @oru.edu
    if (!value.toLowerCase().endsWith('@oru.edu')) {
      return 'Please use your ORU email (@oru.edu)';
    }
    
    return null;
  }
  
  //*********************************************************************************
  // Validates password meets minimum requirements
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    
    // Check minimum length requirement (8 characters)
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    return null;
  }
  
  //*********************************************************************************
  //Validates user's full name
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }
    
    // Check minimum length (at least 2 characters)
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    return null;
  }
}