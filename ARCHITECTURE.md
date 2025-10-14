# Architecture Overview

This document provides an overview of the macOS Support Tools architecture.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     macOS Support Tools                     │
│                    (Menu Bar Application)                   │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
         ┌────▼────┐                    ┌────▼────┐
         │   UI    │                    │ System  │
         │  Layer  │                    │  Layer  │
         └────┬────┘                    └────┬────┘
              │                               │
    ┌─────────┴─────────┐        ┌──────────┴──────────┐
    │                   │        │                     │
┌───▼────┐      ┌──────▼─────┐  │  ┌──────────────┐  │
│MenuBar │      │  Content   │  │  │   IOKit HID  │  │
│Manager │      │    View    │  │  │   Manager    │  │
└────────┘      └────────────┘  │  └──────┬───────┘  │
                                 │         │          │
                                 │  ┌──────▼───────┐  │
                                 │  │ Core Graphics│  │
                                 │  │  Event Tap   │  │
                                 │  └──────┬───────┘  │
                                 │         │          │
                                 │  ┌──────▼───────┐  │
                                 │  │   Service    │  │
                                 │  │  Management  │  │
                                 │  └──────────────┘  │
                                 └─────────────────────┘
```

## Component Description

### UI Layer

#### MenuBarManager
- **Purpose**: Main menu bar interface
- **Responsibilities**:
  - Display menu bar icon
  - Show popup menu with controls
  - Toggle switches for settings
  - Launch at login control
  - Quit button
- **Technologies**: SwiftUI

#### ContentView
- **Purpose**: Main window view (optional)
- **Responsibilities**:
  - Display connection status
  - Show current settings
  - Provide additional controls
- **Technologies**: SwiftUI

### System Layer

#### MouseManager
- **Purpose**: Core business logic for mouse management
- **Responsibilities**:
  - Detect mouse devices
  - Manage device connections/disconnections
  - Store and retrieve device settings
  - Control scroll direction
  - Handle mouse button events
- **Technologies**: Swift, Observation framework
- **Key Features**:
  - Observable state management
  - UserDefaults persistence
  - Device tracking

#### IOKit HID Manager
- **Purpose**: Hardware device detection
- **Responsibilities**:
  - Enumerate connected HID devices
  - Filter for mouse devices
  - Monitor device connection changes
  - Extract device information (vendor ID, product ID, name)
- **Technologies**: IOKit.hid
- **Events**:
  - Device added callback
  - Device removed callback

#### Core Graphics Event Tap
- **Purpose**: Intercept and modify system events
- **Responsibilities**:
  - Tap scroll events
  - Reverse scroll direction when needed
  - Tap mouse button events
  - Control button behavior
- **Technologies**: Core Graphics, CGEvent
- **Permissions Required**: Accessibility

#### Service Management
- **Purpose**: Launch at login functionality
- **Responsibilities**:
  - Register/unregister app for launch at login
  - Query login item status
- **Technologies**: ServiceManagement framework
- **Requirements**: macOS 13.0+

## Data Models

### MouseDevice
```swift
struct MouseDevice: Codable, Identifiable {
    let id: String              // Unique device identifier
    let name: String             // Device name
    let vendorID: Int           // USB vendor ID
    let productID: Int          // USB product ID
    var naturalScrollEnabled: Bool
    var lastConnected: Date
    var leftButtonEnabled: Bool
    var rightButtonEnabled: Bool
    var middleButtonEnabled: Bool
    var button4Enabled: Bool
    var button5Enabled: Bool
    var button4Action: MouseButtonAction
    var button5Action: MouseButtonAction
}
```

### MouseButtonAction
```swift
enum MouseButtonAction: CaseIterable, Codable {
    case none
    case back
    case forward
    case middleClick
    case custom
}
```

## State Management

### Observable Pattern
The app uses Swift's `@Observable` macro for state management:

```swift
@Observable class MouseManager {
    var connectedDevices: [MouseDevice]
    var deviceSettings: [String: MouseDevice]
    var isAnyExternalMouseConnected: Bool
    var naturalScrollEnabled: Bool
    var mouseButtonsEnabled: Bool
    // ...
}
```

### State Flow
```
User Action → SwiftUI View → MouseManager → System API
                                    ↓
                              UserDefaults
                              (Persistence)
```

## Event Flow

### Device Detection Flow
```
1. App Launch
   ↓
2. IOHIDManager Setup
   ↓
3. Device Enumeration
   ↓
4. Initial Device Detection
   ↓
5. Register Callbacks
   ↓
6. Monitor for Changes
```

### Scroll Event Flow
```
1. User Scrolls
   ↓
2. CGEvent Generated
   ↓
3. Event Tap Intercepts
   ↓
4. Check if External Mouse
   ↓
5. Check Natural Scroll Setting
   ↓
6. Reverse Direction (if needed)
   ↓
7. Post Modified Event
```

### Button Event Flow
```
1. User Clicks Button
   ↓
2. CGEvent Generated
   ↓
3. Event Tap Intercepts
   ↓
4. Check Button Configuration
   ↓
5. Execute Mapped Action or Block
   ↓
6. Post Event or Consume
```

## Persistence

### UserDefaults Keys
- `MouseButtonsEnabled`: Global mouse button toggle
- `NaturalScrollEnabled`: Natural scroll preference
- `MouseDeviceSettings`: JSON-encoded device settings

### Storage Format
```json
{
  "device-12345": {
    "id": "device-12345",
    "name": "Logitech Mouse",
    "vendorID": 1133,
    "productID": 45078,
    "naturalScrollEnabled": false,
    "lastConnected": "2025-10-14T00:00:00Z",
    "leftButtonEnabled": true,
    "rightButtonEnabled": true,
    "middleButtonEnabled": true,
    "button4Enabled": true,
    "button5Enabled": true,
    "button4Action": "forward",
    "button5Action": "back"
  }
}
```

## Security Considerations

### Permissions Required

1. **Accessibility Access**
   - Required for: Event tapping
   - Used for: Intercepting scroll and button events
   - Location: System Settings → Privacy & Security → Accessibility

2. **App Sandbox**
   - Enabled in build settings
   - Restrictions: Limited file system access
   - Benefits: Enhanced security

### Data Privacy

- No data sent to external servers
- All data stored locally in UserDefaults
- No analytics or tracking
- No network access required

## Thread Safety

### Main Thread Operations
- All UI updates
- SwiftUI state changes
- UserDefaults writes (handled by system)

### Background Operations
- HID device enumeration
- Event tap callbacks (system-managed)

### Synchronization
- Observable properties automatically dispatch to main thread
- Event tap callbacks use system-managed queues

## Performance Considerations

### Optimization Strategies
1. **Lazy Device Loading**: Devices loaded only when needed
2. **Efficient Event Handling**: Minimal processing in event tap
3. **Cached Settings**: Device settings cached in memory
4. **Debounced Updates**: UI updates batched when possible

### Resource Usage
- Memory: ~10-20 MB typical
- CPU: <1% idle, <5% during events
- No disk I/O during normal operation

## Testing Strategy

### Unit Tests
- Device model tests
- Settings persistence tests
- Button action mapping tests

### UI Tests
- Menu interaction tests
- Toggle state tests
- Launch tests

### Manual Testing
- Device connection/disconnection
- Scroll direction changes
- Button configuration
- Launch at login

## Future Enhancements

Potential architecture improvements:

1. **Modular Device Support**: Plugin system for different device types
2. **Advanced Profiles**: Multiple configuration profiles
3. **Gesture Support**: Detect and configure complex gestures
4. **Cloud Sync**: Optional iCloud sync for settings
5. **Analytics Dashboard**: Show usage statistics (local only)

## Dependencies

### System Frameworks
- SwiftUI: UI framework
- IOKit: Hardware device access
- CoreGraphics: Event system access
- ServiceManagement: Launch at login
- AppKit: macOS app lifecycle
- Foundation: Core utilities

### External Dependencies
- None (pure system frameworks)

## Build Configuration

### Debug
- Code signing: Development
- Optimization: None
- Symbols: Included

### Release
- Code signing: Distribution (optional)
- Optimization: Size + Speed
- Symbols: Stripped
- Bitcode: Yes (if enabled)

---

For implementation details, see the source code files:
- `MouseManager.swift`: Core logic
- `MouseEventHandlers.swift`: Event handling
- `MouseModels.swift`: Data models
- `MenuBarManager.swift`: UI
- `LaunchAtLogin.swift`: Launch at login
