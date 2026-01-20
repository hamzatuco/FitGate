# FitGate Shared Package

Shared code and components for FitGate admin and client applications.

## Contents

### Models
- **Locker** - Represents a gym locker with its properties and status

### Widgets
- **PrimaryButton** - Reusable primary button with loading state support
- **InfoCard** - Information card widget for displaying member information
- **AppTextField** - Reusable text field widget with password toggle

## Usage

Add to your app's `pubspec.yaml`:

```yaml
dependencies:
  fitgate_shared:
    path: ../../shared/fitgate_shared
```

Import in your code:

```dart
import 'package:fitgate_shared/fitgate_shared.dart';

// Use any exported models or widgets
```

## Structure

```
lib/
├── models/
│   ├── locker.dart
│   └── models.dart (barrel export)
├── widgets/
│   ├── primary_button.dart
│   ├── info_card.dart
│   ├── app_text_field.dart
│   └── widgets.dart (barrel export)
└── fitgate_shared.dart (main library export)
```

## Features

- **Reusable Components**: Common widgets used across both admin and client apps
- **Shared Models**: Data models like Locker for consistency
- **Clean Architecture**: Organized structure for easy maintenance

## Development

Run analysis:
```bash
flutter analyze
```

Format code:
```bash
dart format lib/
```
