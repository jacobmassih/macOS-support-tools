# App Icon Documentation

## Overview

This document describes the custom app icon created for the **macOS Support Tools** application.

## Design

The app icon features a modern, professional design that clearly communicates the application's purpose:

- **Blue Gradient Background**: A circular gradient from bright to deep blue, giving a modern macOS appearance
- **Mouse Cursor**: A white arrow cursor representing the mouse management functionality
- **Settings Gear**: A golden gear icon symbolizing the configuration and customization features
- **Shadow Effects**: Professional drop shadows that add depth and visual polish

## Technical Specifications

- **Format**: PNG with alpha transparency
- **Color Space**: sRGB
- **Platform**: macOS 10.13+
- **Location**: `macos-support-tools/Assets.xcassets/AppIcon.appiconset/`

## Generated Files

The following icon files have been generated to support all macOS display resolutions:

| Filename | Dimensions | Purpose |
|----------|------------|---------|
| `icon_16x16.png` | 16×16 | Menu bar, small lists (@1x) |
| `icon_16x16@2x.png` | 32×32 | Menu bar, small lists (@2x) |
| `icon_32x32.png` | 32×32 | Large lists, toolbars (@1x) |
| `icon_32x32@2x.png` | 64×64 | Large lists, toolbars (@2x) |
| `icon_128x128.png` | 128×128 | Finder icon view (@1x) |
| `icon_128x128@2x.png` | 256×256 | Finder icon view (@2x) |
| `icon_256x256.png` | 256×256 | Large Finder icons (@1x) |
| `icon_256x256@2x.png` | 512×512 | Large Finder icons (@2x) |
| `icon_512x512.png` | 512×512 | Retina displays (@1x) |
| `icon_512x512@2x.png` | 1024×1024 | Retina displays (@2x) |

## Usage

The icon is automatically used by macOS when the application is built. No additional configuration is needed.

### Where the Icon Appears

- **Dock**: When the application is running or pinned
- **Finder**: In file browsers and application folder
- **Spotlight**: In search results
- **App Switcher**: When switching between applications (Cmd+Tab)
- **Launchpad**: In the application launcher
- **Menu Bar**: Can be used for menu bar items (currently using SF Symbol)

## Asset Catalog Configuration

The icon is properly configured in `Assets.xcassets/AppIcon.appiconset/Contents.json` with references to all image files. Xcode automatically selects the appropriate icon size based on the display context and resolution.

## Design Rationale

### Color Palette

- **Blue** (#4682E6 to #70B4FF): Represents trust, technology, and professionalism
- **White** (#FFFFFF): Ensures the mouse cursor is clearly visible
- **Gold** (#FFC846): Makes the settings gear stand out as an interactive element

### Symbolism

- **Mouse Cursor**: Immediately identifies this as a mouse-related utility
- **Settings Gear**: Indicates configuration and customization capabilities
- **Circular Design**: Follows macOS Big Sur+ design language with rounded, friendly shapes

## Future Enhancements

Consider updating the `MenuBarExtra` in `macos_support_toolsApp.swift` to use a custom menu bar icon instead of the SF Symbol "computermouse" for a more branded appearance.

## Credits

Icon designed using Python with Pillow (PIL) library, specifically created for the macOS Support Tools project.
