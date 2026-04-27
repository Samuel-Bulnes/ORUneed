# ORUneed User Guide

**Author:** Samuel Bulnes  
**Institution:** Oral Roberts University  

---

## Introduction

This User Guide describes the technical steps required to install, configure, and run the **ORUneed** application locally for development, testing, or evaluation purposes. It is intended for instructors, reviewers, and system administrators who need to execute the project on their own machines.

---

## System Requirements

To run ORUneed locally, the following software and hardware components are required:

- A computer running Windows 10/11, macOS, or Linux
- At least 8 GB of RAM (16 GB recommended)
- Internet connection
- Flutter SDK
- Android Studio
- Android Emulator OR Physical Android Device

---

## Installation

### Installing Flutter

1. Download Flutter from: [https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)
2. Extract Flutter to a directory such as `C:\flutter`
3. Add Flutter to the system PATH.
4. Open a terminal and run:
   ```bash
   flutter doctor
   ```
5. Verify that all dependencies are correctly detected.

### Installing Android Studio and Emulator

1. Install Android Studio.
2. During installation, make sure to include:
   - Android SDK
   - Android Emulator
   - Platform Tools
3. Open Android Studio and create an emulator:
   - **Device:** Pixel or similar
   - **API Level:** 30 or higher

### Installing Dependencies

Inside the project directory, run:

```bash
flutter pub get
```

This command downloads all required Flutter packages.

---

## Downloading the ORUneed Project (ZIP File)

The ORUneed source code is provided as a compressed ZIP file.

1. Download the file named: `ORUneed.zip`
2. Right-click the ZIP file and select **"Extract All…"**
3. Choose a destination folder, for example: `C:\Projects\ORUneed`

This folder will be used to open and run the project with Flutter.

---

## Running the Backend Server (Node.js)

ORUneed requires a backend server for features such as real-time communication and data handling. This server is executed using **Node.js**.

1. Open a new Command Prompt / Terminal window (separate from the Flutter terminal).
2. Navigate to the backend directory inside the project folder:
   ```bash
   cd C:\Projects\ORUneed\backend
   ```
3. Install the required Node.js dependencies (only needed the first time):
   ```bash
   npm install
   ```
4. Start the backend server:
   ```bash
   node server.js
   ```

If the server starts successfully, the terminal will display a message indicating that the server is running (e.g., `Server running on port 3000`).

> **Note:** The backend server must remain running in its own terminal window while ORUneed is active in the Flutter emulator.

---

## Running ORUneed with Flutter (Local Setup)

To run ORUneed from the extracted project using Flutter:

1. Make sure **Flutter** is installed and configured. Verify with:
   ```bash
   flutter doctor
   ```
2. Open a terminal and navigate to the project directory:
   ```bash
   cd C:\Projects\ORUneed
   ```
3. Install all project dependencies:
   ```bash
   flutter pub get
   ```
4. Start an Android emulator from Android Studio or with:
   ```bash
   flutter emulators --launch <emulator_id>
   ```
5. Once the emulator is running, launch the application:
   ```bash
   flutter run
   ```

The ORUneed application will build and launch inside the selected emulator.

---

## User Guide

### Creating an Account

1. Open the ORUneed application.
2. Select the **"Sign Up"** option.
3. Enter your ORU email address, password, and any required personal information.
4. Submit the registration form.
5. Check your ORU email inbox for a verification message (check the Mimecast Panel).
6. Click the verification link to confirm your account.

Once your email is verified, your account will be activated and ready for use.

---

### Logging In and Out

**Logging In:**

1. Open the ORUneed application.
2. Select **"Log In"**.
3. Enter your ORU email address and password.
4. Click **"Submit"** to access your account.

**Logging Out:**

1. Open the Profile section.
2. Select **"Log Out"**.
3. Confirm the logout action.

---

### Navigating the Application

The main navigation system of ORUneed includes the following sections:

| Section | Description |
|---------|-------------|
| **Home** | Displays active job postings |
| **Post** | Allows users to create a new job request |
| **Chat** | Provides real-time messaging |
| **History** | Shows completed and pending job records |
| **Profile** | Allows users to view and edit personal information |

Users navigate between these sections using the bottom navigation bar or main menu.

---

### Creating a Job Post

1. Navigate to the **Post** section.
2. Enter a job title (e.g., "Help Moving Furniture").
3. Enter a job description explaining the task, location, and expected duration.
4. Enter the payment or compensation amount.
5. Add optional details such as time and date.
6. Click **"Submit"** or **"Post Job"**.

After submission, the job post becomes visible to other users.

---

### Browsing and Accepting Jobs

**Browsing Jobs:**

1. Navigate to the **View Jobs** section.
2. Scroll through available job listings.
3. Click on a job to view its details.

**Accepting a Job:**

1. After reviewing the job details, click **"Accept Job"**.
2. The job requester will receive a notification.
3. Use the **Chat** feature to confirm time, location, and expectations.

Once the job is completed, both users can view the record in their job history.

---

### Using the Chat Feature

The Chat feature allows real-time communication between users.

1. Open the **Chat** section.
2. Select a conversation linked to an active or accepted job.
3. Enter your message.
4. Press **"Send"** to deliver the message.

The chat is used to clarify job details, confirm meeting times, and provide updates.
