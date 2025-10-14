# Changelog

All notable changes to macOS Support Tools will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-14

### Added
- Menu bar application for mouse management
- Natural scroll toggle for external mice
- Automatic detection of external mouse devices via IOKit HID
- Device-specific mouse button configuration
- Support for configuring side buttons (Button 4 and Button 5)
- Mouse button action mapping (Back, Forward, Middle Click)
- Launch at login support for macOS 13.0+
- UserDefaults persistence for settings
- Mouse device settings per-device configuration
- Real-time mouse connection/disconnection detection

### Features
- **Natural Scroll Control**: Toggle natural scrolling on/off for external mice
- **Mouse Button Management**: Enable/disable mouse buttons globally
- **Launch at Login**: Configure app to start automatically at login
- **Device Detection**: Automatic detection and tracking of connected mouse devices
- **Menu Bar Integration**: Clean, minimal menu bar interface for quick access
- **Settings Persistence**: All configurations saved and restored between sessions

### Technical Details
- Built with SwiftUI for macOS
- Uses IOKit HID for device management
- Core Graphics event tapping for scroll direction control
- Service Management for launch at login functionality
- Observable pattern for state management

[1.0.0]: https://github.com/jacobmassih/macOS-support-tools/releases/tag/v1.0.0
