# FitGate

FitGate is a multi-platform fitness application suite designed to help users manage their fitness journey, track progress, and access personalized workout and nutrition plans. The project consists of several apps and shared libraries, including admin and client apps, Firebase functions, and microcontroller integration.

## Project Structure

```
FitGate/
├── apps/
│   ├── fitgate_admin/      # Admin Flutter app for managing users and content
│   └── fitgate_client/     # Client Flutter app for end users
├── fitgate-firebase-functions/ # Firebase Cloud Functions backend
├── fitgate-mcu/            # Microcontroller (Arduino) integration
├── shared/
│   └── fitgate_shared/     # Shared Dart code and models
└── firebase.json           # Firebase project configuration
```

## Features

- **User Management**: Registration, login, and profile editing
- **Workout Plans**: Personalized workout routines
- **Nutrition Tracking**: Meal plans and calorie tracking
- **Progress Tracking**: Visualize fitness progress
- **Admin Panel**: Manage users, content, and analytics
- **Cloud Integration**: Firebase for authentication, database, and functions
- **IoT Integration**: Microcontroller support for fitness devices

## Getting Started

### Prerequisites
- [Flutter](https://flutter.dev/docs/get-started/install)
- [Dart](https://dart.dev/get-dart)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- [Node.js](https://nodejs.org/)
- [Arduino IDE](https://www.arduino.cc/en/software) (for MCU)

### Setup
1. **Clone the repository:**
	 ```sh
	 git clone <repo-url>
	 cd FitGate
	 ```
2. **Install dependencies:**
	 - For Flutter apps:
		 ```sh
		 cd apps/fitgate_client
		 flutter pub get
		 cd ../fitgate_admin
		 flutter pub get
		 ```
	 - For Firebase Functions:
		 ```sh
		 cd fitgate-firebase-functions/functions
		 npm install
		 ```
3. **Configure Firebase:**
	 - Set up your Firebase project and update `google-services.json` and `firebase_options.dart` in each app.
	 - Deploy indexes and functions as needed:
		 ```sh
		 firebase deploy --only firestore,indexes,functions
		 ```
4. **Run the apps:**
	 - Client/Admin:
		 ```sh
		 flutter run
		 ```
	 - MCU:
		 - Open `fitgate-mcu/FitGate/FitGate.ino` in Arduino IDE and upload to your device.

## Folder Overview

- `apps/fitgate_client/` - Main user-facing Flutter app
- `apps/fitgate_admin/` - Admin Flutter app
- `fitgate-firebase-functions/` - Cloud backend (Node.js)
- `fitgate-mcu/` - Arduino code for hardware integration
- `shared/fitgate_shared/` - Shared Dart code (models, widgets)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/YourFeature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/YourFeature`)
5. Open a pull request

## License

This project is licensed under the MIT License.

---

For more information, see the documentation in each subfolder or contact the project maintainers.
