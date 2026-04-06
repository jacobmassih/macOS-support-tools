# macos-support-tools

Small macOS utility app for mouse-related support tooling.

## What it does

- Detects connected external mice with `IOHIDManager`
- Optionally reverses mouse wheel scrolling without affecting trackpad momentum scrolling
- Intercepts side-button mouse events to map them to back/forward or middle click actions
- Disables custom side-button handling while Citrix Workspace is frontmost
- Offers a menu bar UI and optional launch-at-login support

## Permissions and trust

This app uses macOS Accessibility permissions because it installs event taps to observe and modify mouse input events. It does not contain network code, remote telemetry, or embedded API credentials in this repository.

Because it changes input behavior at the system level, review the source before running it and only grant Accessibility access if you are comfortable with that capability.

## Development notes

- The checked-in project is intentionally free of personal signing metadata.
- CI builds and tests run without code signing.
- Full local builds require Xcode, not just Command Line Tools.
