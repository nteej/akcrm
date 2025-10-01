# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FinnERP is an ERP Software System for Finnish small and medium-sized enterprises built with Flutter. The app provides authentication, job tracking, location services, timesheet management, and income tracking capabilities.

## Development Commands

### Build and Run
- `flutter run` - Run the app in development mode
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app
- `flutter build web` - Build web app

### Testing and Quality
- `flutter test` - Run all tests
- `flutter analyze` - Run static analysis and linting
- `flutter pub get` - Install dependencies
- `flutter pub upgrade` - Upgrade dependencies

### Platform-specific
- `flutter run -d chrome` - Run on web browser
- `flutter run -d ios` - Run on iOS simulator
- `flutter run -d android` - Run on Android emulator

## Architecture

### State Management
- Uses **Provider** pattern for state management
- Main provider: `Auth` class in `lib/providers/auth.dart` handles authentication state
- Authentication state persisted using `flutter_secure_storage`

### API Integration
- HTTP client: **Dio** configured in `lib/helper/dio.dart`
- Base URL: `https://akcrm.ovh/api`
- Authentication: Bearer token with device ID tracking
- All API requests include device ID for tracking

### Key Components

**Authentication Flow:**
- `lib/providers/auth.dart` - Authentication provider with login/register/logout
- `lib/screen/login_screen.dart` - Login UI
- `lib/screen/register.dart` - Registration UI
- Token storage via secure storage with device ID binding

**Main Navigation:**
- `lib/main.dart` - App entry point with Provider setup
- `lib/screen/home.dart` - Main home screen with navigation
- Consumer pattern used for reactive UI updates

**Core Features:**
- **Job Management:** `lib/screen/job_page.dart`, `lib/screen/job_details_page.dart`
- **Location Services:** `lib/screen/location_page.dart`, `lib/screen/map_page.dart`, `lib/screen/google_map_page.dart`
- **Timesheet:** `lib/widgets/timesheet_tile.dart`
- **Income Tracking:** `lib/screen/income_page.dart`
- **Posts/Communication:** `lib/screen/posts_screen.dart`

### Models
- `lib/models/user.dart` - User data model
- `lib/models/job.dart` - Job data model
- `lib/models/post.dart` - Post data model
- `lib/models/error.dart` - Error handling model

### UI Components
- `lib/widgets/custom_button.dart` - Reusable button component
- `lib/widgets/custom_textformfield.dart` - Form input component
- `lib/widgets/custom_snack_bar.dart` - Notification component
- `lib/widgets/navdrawer.dart` - Navigation drawer

### Configuration
- `lib/config/app_colors.dart` - App color scheme
- `lib/config/string.dart` - String constants
- `assets/images/` - Image assets

## Dependencies

Key packages:
- `provider` - State management
- `dio` - HTTP client
- `flutter_secure_storage` - Secure token storage
- `geolocator` - Location services
- `google_maps_flutter` - Map integration
- `image_picker` - Image selection
- `platform_device_id` - Device identification

## Testing

- Basic widget test available in `test/widget_test.dart`
- Uses `flutter_test` framework
- Run tests with `flutter test`

## Platform Support

The app supports:
- Android (with native Android configuration)
- iOS (with native iOS configuration)
- Web (basic web support)
- macOS, Linux, Windows (configured but may need platform-specific testing)