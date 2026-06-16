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
It also requires Input Monitoring permission to detect connected mouse devices through `IOHIDManager`.
Those permissions are necessary for features like scroll-direction changes and side-button remapping.

Because these are privileged capabilities, you should review the source and only grant access if you are comfortable with how the app works.

## Install With Homebrew

```bash
brew tap jacobmassih/tap
brew install --cask macos-support-tools
```

The Homebrew cask installs the signed and notarized GitHub release build.

The app also requires Accessibility and Input Monitoring permissions for mouse event handling.

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
- PR CI is configured to build without code signing.
- Release CI signs and notarizes distributable app archives.
- The app is not sandboxed because its input-event behavior depends on macOS APIs that require broader access.

## Local Signing For Xcode

If you want to run the app locally from Xcode with a stable signing identity, create `Config/LocalSigning.xcconfig` on your machine.

The easiest option is:

```bash
./scripts/setup-local-signing.sh YOUR_TEAM_ID
```

You can find your Apple Developer Team ID in Xcode under:

- `Xcode > Settings > Accounts`
- select your Apple ID
- select your team

If you prefer to do it manually, create `Config/LocalSigning.xcconfig` with:

```xcconfig
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

This file is ignored by git and is included automatically by the shared project configuration.

## Releases

GitHub releases are created automatically when a version tag is pushed:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The release workflow builds the app in Release configuration, signs it with Developer ID, notarizes and staples it, packages `macos-support-tools.app` as a zip archive, and uploads a SHA-256 checksum file alongside it. The zip URL and checksum are used by the Homebrew cask in [`jacobmassih/homebrew-tap`](https://github.com/jacobmassih/homebrew-tap).

Release automation requires these repository secrets:

- `HOMEBREW_TAP_TOKEN`: GitHub token with write access to `jacobmassih/homebrew-tap`
- `DEVELOPER_ID_CERTIFICATE_BASE64`: base64-encoded `.p12` export of the Developer ID Application certificate
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`: password for the `.p12` certificate export
- `APPLE_ID`: Apple ID used for notarization
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for that Apple ID
- `APPLE_TEAM_ID`: Apple Developer Team ID

The app requires Accessibility and Input Monitoring permissions after install. Signed releases keep a stable Developer ID identity across versions, which avoids the permission churn caused by ad-hoc-signed builds.

## License

This project is released under the MIT License. See [`LICENSE`](LICENSE).
