# macOS Support Tools

A native macOS menu bar application for managing external mouse settings and behavior.

## Features

### 🖱️ Mouse Management
- **Natural Scroll Control**: Toggle natural scrolling on/off specifically for external mice
- **Mouse Button Configuration**: Enable/disable mouse buttons and configure side button actions
- **Device Detection**: Automatic detection of connected/disconnected external mice
- **Per-Device Settings**: Customize settings for each mouse device individually

### 🚀 System Integration
- **Menu Bar App**: Lightweight menu bar application for quick access
- **Launch at Login**: Option to start automatically when you log in (macOS 13.0+)
- **Settings Persistence**: All your preferences are saved automatically

### ⚙️ Customization
- Configure side button actions (Button 4 & 5)
- Set custom actions: Back, Forward, Middle Click
- Device-specific configurations

## Requirements

- macOS 13.0 or later
- Accessibility permissions (for mouse event handling)

## Installation

### From Release
1. Download the latest release from the [Releases](https://github.com/jacobmassih/macOS-support-tools/releases) page
2. Extract the downloaded archive
3. Move `macos-support-tools.app` to your Applications folder
4. Launch the app
5. Grant Accessibility permissions when prompted (System Settings → Privacy & Security → Accessibility)

### Building from Source
1. Clone this repository:
   ```bash
   git clone https://github.com/jacobmassih/macOS-support-tools.git
   cd macOS-support-tools
   ```

2. Open the project in Xcode:
   ```bash
   open macos-support-tools.xcodeproj
   ```

3. Build and run the project (⌘R)

## Usage

1. Launch the application
2. Find the mouse icon in your menu bar
3. Click the icon to access the menu:
   - **Natural Scroll**: Toggle natural scrolling for external mice
   - **Mouse Buttons**: Enable/disable mouse button functionality
   - **Launch at Login**: Start app automatically at login
   - **Settings**: Access advanced configuration (coming soon)
   - **Quit**: Exit the application

### Permissions

The app requires Accessibility permissions to:
- Detect external mouse devices
- Intercept and modify scroll events
- Handle mouse button events

When you first launch the app, macOS will prompt you to grant these permissions.

## Architecture

- **SwiftUI**: Modern declarative UI framework
- **IOKit HID**: Low-level device detection and management
- **Core Graphics**: Event tapping for scroll direction control
- **Service Management**: Launch at login functionality
- **Observable**: State management with Swift's Observation framework

## Project Structure

```
macos-support-tools/
├── macos-support-tools/          # Main application
│   ├── macos_support_toolsApp.swift    # App entry point
│   ├── MenuBarManager.swift            # Menu bar UI
│   ├── MouseManager.swift              # Mouse device management
│   ├── MouseEventHandlers.swift        # Event handling logic
│   ├── MouseModels.swift               # Data models
│   ├── MouseDevice+Extensions.swift    # Device extensions
│   ├── LaunchAtLogin.swift            # Launch at login support
│   └── ContentView.swift              # Main content view
├── macos-support-toolsTests/     # Unit tests
└── macos-support-toolsUITests/   # UI tests
```

## Development

### Running Tests

```bash
xcodebuild test \
  -project macos-support-tools.xcodeproj \
  -scheme macos-support-tools \
  -destination 'platform=macOS,arch=arm64'
```

### Building for Release

```bash
xcodebuild clean build \
  -project macos-support-tools.xcodeproj \
  -scheme macos-support-tools \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64'
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is created by Jacob Massih.

## Acknowledgments

- Built for macOS users who need better control over external mouse behavior
- Inspired by the need for flexible scroll direction management

## Support

For issues, questions, or feature requests, please [open an issue](https://github.com/jacobmassih/macOS-support-tools/issues) on GitHub.

---

Made with ❤️ by [Jacob Massih](https://github.com/jacobmassih)
