# DriveNotes

A Flutter application that allows users to create, edit, and manage notes that are synced with Google Drive.

## Features

- Google OAuth 2.0 authentication
- Create, edit, and delete notes
- Notes are stored as text files in Google Drive
- Material 3 design with responsive UI
- Secure token storage
- Error handling and loading states
- Swipe to delete notes
- Token refresh handling

## Setup

1. Create a Google Cloud Console project:
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Create a new project
   - Enable the Google Drive API
   - Configure the OAuth consent screen
   - Create OAuth 2.0 credentials (Web application type)
   - Add your redirect URIs

2. Update the client ID and secret:
   - Open `lib/features/notes/data/drive_service.dart`
   - Replace `your-client-id` and `your-client-secret` with your actual credentials

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── features/
│   └── notes/
│       ├── data/
│       │   └── drive_service.dart      # Google Drive API integration
│       ├── domain/
│       │   └── models/
│       │       └── note_model.dart     # Note data model
│       └── presentation/
│           ├── pages/
│           │   └── notes_list_page.dart # Notes list UI
│           └── providers/
│               ├── note_editor_controller.dart  # Note editing logic
│               └── notes_controller.dart        # Notes list logic
├── login.dart                          # Login page
└── main.dart                           # App entry point and routing
```

## Dependencies

- `flutter_riverpod`: State management
- `go_router`: Navigation
- `googleapis`: Google Drive API
- `flutter_secure_storage`: Secure token storage
- `google_sign_in`: Google authentication

## Known Limitations

- No offline support
- No dark mode theme switching
- No background sync
- Limited error recovery options
- No file conflict resolution

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request
