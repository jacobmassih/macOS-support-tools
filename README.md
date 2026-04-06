# macos-support-tools

`macos-support-tools` is a small macOS menu bar app focused on mouse behavior tweaks.
It is built for a simple use case: make external mouse scrolling and side-button behavior easier to control without adding cloud services, accounts, or background telemetry.

## Features

- Detects connected external mice with `IOHIDManager`
- Reverses external mouse wheel scrolling while avoiding trackpad momentum scrolling
- Remaps side mouse buttons to back, forward, or middle click behavior
- Temporarily skips custom side-button handling when Citrix Workspace is the frontmost app
- Supports launch at login
- Runs as a menu bar utility instead of a full Dock app

## How It Works

The app installs macOS event taps to observe and optionally modify mouse input events in the current user session. Mouse-related preferences are stored locally with `UserDefaults`.

This repository does not include:

- network calls
- analytics or telemetry
- API keys or external service credentials
- bundled third-party backend dependencies

## Permissions

The app requires macOS Accessibility permission in order to monitor and adjust input events.
That permission is necessary for features like scroll-direction changes and side-button remapping.

Because this is a privileged capability, you should review the source and only grant Accessibility access if you are comfortable with how the app works.

## Building

### Requirements

- macOS
- Xcode

Full builds require the full Xcode app. Command Line Tools alone are not enough for `xcodebuild` in this project.

### Open In Xcode

1. Open `macos-support-tools.xcodeproj`.
2. Select the `macos-support-tools` scheme.
3. Build and run the app from Xcode.

## Notes

- The project is intentionally checked in without personal signing metadata.
- CI is configured to build without code signing.
- The app is not sandboxed because its input-event behavior depends on macOS APIs that require broader access.

## License

This project is released under the MIT License. See [`LICENSE`](LICENSE).
