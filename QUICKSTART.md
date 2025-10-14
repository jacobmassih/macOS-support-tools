# Quick Start Guide

Get started with macOS Support Tools in minutes!

## Installation

### Download and Install

1. **Download**: Get the latest release from [GitHub Releases](https://github.com/jacobmassih/macOS-support-tools/releases/latest)

2. **Extract**: Double-click the downloaded `.zip` file to extract it

3. **Install**: Drag `macos-support-tools.app` to your Applications folder

4. **Launch**: Double-click the app in Applications

### First Launch

On first launch, you'll need to grant permissions:

1. **Open the app**: Find it in Applications and double-click
2. **Grant Accessibility Permission**: 
   - macOS will prompt you to grant accessibility permissions
   - Click "Open System Settings"
   - Enable the toggle next to "macos-support-tools"
   - Restart the app

## Basic Usage

### Finding the App

After launch, you'll see a computer mouse icon (🖱️) in your menu bar at the top-right of your screen.

### Menu Bar Controls

Click the menu bar icon to access:

**Natural Scroll Toggle**
- ✅ ON: Scroll like on a trackpad (content follows finger direction)
- ❌ OFF: Traditional scroll (content moves opposite to scroll direction)

**Mouse Buttons Toggle**
- ✅ ON: All mouse buttons work normally
- ❌ OFF: Mouse buttons are disabled

**Launch at Login**
- ✅ ON: App starts automatically when you log in
- ❌ OFF: You need to start the app manually

**Quit**
- Exits the application

## Common Use Cases

### Use Case 1: Different Scroll for Mouse and Trackpad

**Scenario**: You want natural scrolling on your trackpad but traditional scrolling on your external mouse.

**Solution**:
1. Enable Natural Scrolling in System Settings (for trackpad)
2. Launch macOS Support Tools
3. Turn OFF "Natural Scroll" in the app (for external mouse)

Result: Trackpad uses natural scroll, mouse uses traditional scroll!

### Use Case 2: Start App Automatically

**Scenario**: You always use an external mouse and want the app ready when you log in.

**Solution**:
1. Click the menu bar icon
2. Enable "Launch at Login"
3. The app will now start automatically!

### Use Case 3: Temporarily Disable Mouse Buttons

**Scenario**: You're cleaning your mouse and don't want accidental clicks.

**Solution**:
1. Click the menu bar icon
2. Turn OFF "Mouse Buttons"
3. Clean your mouse without worry!
4. Turn "Mouse Buttons" back ON when done

## Troubleshooting

### App Icon Not Showing in Menu Bar

**Solutions**:
- Check if the app is running (look in Activity Monitor)
- Restart the app
- Check menu bar settings (Control Center preferences)

### Scroll Direction Not Changing

**Solutions**:
1. Verify Accessibility permissions are granted
2. Disconnect and reconnect your mouse
3. Restart the app
4. Check the Natural Scroll toggle is in the correct state

### Launch at Login Not Working

**Solutions**:
1. Verify you're on macOS 13.0 or later
2. Check System Settings → General → Login Items
3. Remove and re-add the launch at login permission
4. Restart your Mac

### Permission Denied Errors

**Solutions**:
1. Go to System Settings → Privacy & Security → Accessibility
2. Find "macos-support-tools" in the list
3. Toggle it OFF then ON again
4. Restart the app

## Tips and Tricks

### Quick Toggle

Create a keyboard shortcut to quickly toggle the app settings (requires third-party tools like BetterTouchTool or Keyboard Maestro).

### Multiple Mice

The app detects all connected external mice automatically. Settings apply to all external mice.

### System Settings Integration

The app respects your System Settings for trackpad. It only affects external mice.

## Next Steps

- Read the full [README](../README.md) for detailed information
- Check [CHANGELOG](../CHANGELOG.md) for latest features
- Report issues on [GitHub Issues](https://github.com/jacobmassih/macOS-support-tools/issues)
- Contribute to the project (see [CONTRIBUTING](../CONTRIBUTING.md))

## Getting Help

If you encounter any issues:

1. Check this guide first
2. Look for similar issues in [GitHub Issues](https://github.com/jacobmassih/macOS-support-tools/issues)
3. Check the Console app for error messages (filter by "macos-support-tools")
4. Open a new issue with details about your problem

## Uninstallation

To remove the app:

1. Quit the app (click menu bar icon → Quit)
2. Move `macos-support-tools.app` from Applications to Trash
3. (Optional) Remove from Login Items in System Settings
4. (Optional) Remove Accessibility permissions in System Settings

---

Enjoy using macOS Support Tools! 🎉
