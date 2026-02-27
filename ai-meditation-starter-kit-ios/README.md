# AI Meditation

AI Meditation iOS app

## Setup

1. Make sure you have [Tuist](https://tuist.io) installed:
   ```bash
   curl -Ls https://install.tuist.io | bash
   ```

2. Install dependencies:
   ```bash
   tuist install
   ```

3. Generate the Xcode project:
   ```bash
   tuist generate
   ```

4. Open the workspace:
   ```bash
   open AiMeditation.xcworkspace
   ```

## Project Structure

```
ai-meditation/
├── Project.swift           # Tuist project configuration
├── Tuist/
│   └── Package.swift       # Swift package dependencies
├── AiMeditation/
│   ├── AiMeditationApp.swift
│   ├── Constants.swift
│   ├── HomeView.swift
│   └── Assets.xcassets/
├── AiMeditationTests/
└── AiMeditationUITests/
```

## Dependencies

- **OpenbaseShared** - iOS authentication utilities for Django AllAuth backends

## Configuration

Update `Constants.swift` with your API URLs:

```swift
static var apiBaseUrl: String {
    "https://your-api.com"
}
```
