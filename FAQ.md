# Frequently Asked Questions (FAQ)

## General Questions

### What is macOS Support Tools?

macOS Support Tools is a menu bar application that gives you fine-grained control over external mouse behavior on macOS. It allows you to have different scroll directions for your trackpad and external mouse, configure mouse buttons, and more.

### Is it free?

Yes! macOS Support Tools is open-source and completely free to use.

### What macOS versions are supported?

macOS 13.0 (Ventura) or later is required. Some features (like Launch at Login) require macOS 13.0+.

### Is my data safe?

Absolutely! The app:
- Stores all settings locally on your Mac
- Does not collect any telemetry or analytics
- Does not connect to the internet
- Does not share any data with third parties
- Is open-source so you can verify yourself

## Installation & Setup

### How do I install the app?

1. Download the latest release ZIP from [GitHub Releases](https://github.com/jacobmassih/macOS-support-tools/releases)
2. Extract the ZIP file
3. Move the app to your Applications folder
4. Launch it
5. Grant Accessibility permissions when prompted

### Why does the app need Accessibility permissions?

The app needs Accessibility permissions to:
- Detect when you're using an external mouse
- Intercept scroll events to change their direction
- Handle mouse button events

Without these permissions, the app cannot function properly.

### The app won't launch, what should I do?

If you see a security warning:
1. Go to System Settings → Privacy & Security
2. Look for a message about the blocked app
3. Click "Open Anyway"
4. Confirm you want to open it

Alternatively, right-click the app and select "Open" the first time.

### How do I grant Accessibility permissions?

1. Open System Settings
2. Go to Privacy & Security
3. Click on Accessibility
4. Find "macos-support-tools" in the list
5. Toggle it ON
6. Restart the app

## Features & Usage

### How does scroll direction work?

The app monitors your scroll events. When you scroll with an external mouse and "Natural Scroll" is OFF in the app:
- The scroll direction is reversed compared to macOS system settings
- This allows you to have natural scrolling on your trackpad but traditional scrolling on your mouse

### Can I have different settings for different mice?

Not currently in version 1.0, but this feature is planned for a future release. Currently, settings apply to all external mice.

### What mouse buttons are supported?

- Left button
- Right button
- Middle button (scroll wheel click)
- Button 4 (typically back button)
- Button 5 (typically forward button)

### How do I configure mouse button actions?

In version 1.0, you can enable/disable all mouse buttons globally. Per-button configuration is implemented in the code but not yet exposed in the UI. This will be available in a future update.

### Does the app work with Bluetooth mice?

Yes! The app works with both USB and Bluetooth mice.

### Does the app work with gaming mice?

Yes, the app should work with most gaming mice. However, some gaming mice with proprietary software might have conflicts.

### Can I use this with Magic Mouse?

Magic Mouse is considered a trackpad by macOS, so it's not affected by this app. The app only affects external mice.

## Troubleshooting

### The scroll direction isn't changing

**Possible solutions**:
1. Check that Accessibility permissions are granted
2. Disconnect and reconnect your mouse
3. Toggle the Natural Scroll setting OFF and ON
4. Restart the app
5. Check if your mouse is detected (you should see a green indicator)

### The app says "No external mouse" but one is connected

**Possible solutions**:
1. Unplug and replug the mouse (USB)
2. Turn Bluetooth off and on (Bluetooth mice)
3. Restart the app
4. Check if the mouse works in other apps
5. Try a different USB port

### Launch at Login doesn't work

**Possible solutions**:
1. Make sure you're on macOS 13.0 or later
2. Check System Settings → General → Login Items
3. Remove the app from Login Items and re-add it using the toggle
4. Restart your Mac

### The menu bar icon disappeared

**Possible solutions**:
1. Check if the app is still running (Activity Monitor)
2. Restart the app
3. Check if the icon is hidden in the menu bar (try clicking the control center area)
4. Restart your Mac

### Mouse buttons aren't working

**Possible solutions**:
1. Check that "Mouse Buttons" toggle is ON in the app
2. Check Accessibility permissions
3. Restart the app
4. Check if the mouse buttons work in other apps

### The app crashes on launch

**Possible solutions**:
1. Check Console.app for error messages
2. Make sure you're on macOS 13.0 or later
3. Try removing and re-granting Accessibility permissions
4. Delete UserDefaults: `defaults delete com.mst.macos-support-tools`
5. Reinstall the app
6. Report the issue on GitHub with crash logs

### High CPU usage

The app should use minimal CPU (<1% idle). If you see high usage:
1. Restart the app
2. Check for conflicting apps (other mouse/trackpad utilities)
3. Report the issue on GitHub

## Advanced

### Where are settings stored?

Settings are stored in macOS UserDefaults at:
```
~/Library/Preferences/com.mst.macos-support-tools.plist
```

### How do I reset all settings?

```bash
defaults delete com.mst.macos-support-tools
```

Then restart the app.

### Can I build the app from source?

Yes! The app is open-source. See the [README](README.md) for build instructions.

### How do I contribute to the project?

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

### Can I use this on multiple Macs?

Yes! Install the app on each Mac. Settings are stored locally and don't sync between machines (yet).

### Does the app work in recovery mode or safe mode?

No, the app requires full macOS functionality including Accessibility services, which are not available in recovery or safe mode.

### Can I automate the app with scripts?

The app doesn't currently have a scripting interface, but you could control it using Accessibility APIs or AppleScript (future feature).

## Compatibility

### Does it work with other mouse utilities?

It may conflict with other utilities that modify mouse behavior, such as:
- SteerMouse
- USB Overdrive
- BetterTouchTool (mouse features)
- Logitech Options/Options+

You may need to disable conflicting features in those apps.

### Does it work with virtual machines?

The app works on the host macOS system. It does not affect mouse behavior inside virtual machines.

### Does it work with Remote Desktop?

The app affects the local system. Remote Desktop sessions have their own mouse handling.

## Privacy & Security

### Does the app collect any data?

No! The app does not collect, transmit, or share any data. Everything stays on your Mac.

### Is the source code auditable?

Yes! The entire source code is available on [GitHub](https://github.com/jacobmassih/macOS-support-tools). You can review it yourself.

### Can I trust the pre-built releases?

The releases are built by GitHub Actions from the source code. You can verify the workflow file and build the app yourself if you prefer.

### Does the app update automatically?

No, you need to manually download and install updates from the releases page. Automatic updates may be added in a future version.

## Getting Help

### Where can I report bugs?

Report bugs on [GitHub Issues](https://github.com/jacobmassih/macOS-support-tools/issues) using the bug report template.

### Where can I request features?

Request features on [GitHub Issues](https://github.com/jacobmassih/macOS-support-tools/issues) using the feature request template.

### How can I get support?

1. Check this FAQ first
2. Check existing [GitHub Issues](https://github.com/jacobmassih/macOS-support-tools/issues)
3. Open a new issue with details
4. For general questions, use [GitHub Discussions](https://github.com/jacobmassih/macOS-support-tools/discussions)

### Is there a community?

You can connect with other users and developers through:
- GitHub Issues (for bugs and features)
- GitHub Discussions (for questions and ideas)
- Pull Requests (for contributions)

---

**Didn't find your answer?** Open an issue on [GitHub](https://github.com/jacobmassih/macOS-support-tools/issues) and we'll help you out!
