# Release Process Guide

This document describes how to create and publish a new release for macOS Support Tools.

## Pre-Release Checklist

Before creating a release, ensure:

- [ ] All planned features and fixes are merged to main branch
- [ ] Tests pass successfully
- [ ] Version number has been updated
- [ ] CHANGELOG.md has been updated with the new version
- [ ] Documentation is up to date
- [ ] No known critical bugs

## Version Numbers

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (e.g., 1.0.0)
- **MAJOR**: Breaking changes
- **MINOR**: New features (backwards compatible)
- **PATCH**: Bug fixes (backwards compatible)

## Release Methods

### Method 1: Automated Release (Recommended)

The project has an automated release workflow that can be triggered in two ways:

#### Option A: Create and Push a Git Tag

```bash
# Update version in CHANGELOG.md first
git add CHANGELOG.md
git commit -m "Prepare release v1.0.0"
git push origin main

# Create and push tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

The GitHub Actions workflow will automatically:
1. Build the application
2. Run tests
3. Create a ZIP archive
4. Generate release notes from CHANGELOG.md
5. Create a GitHub release with assets

#### Option B: Manual Workflow Trigger

1. Go to the GitHub repository
2. Navigate to Actions → Create Release
3. Click "Run workflow"
4. Enter the version number (e.g., 1.0.0)
5. Click "Run workflow"

### Method 2: Manual Release

If the automated workflow is not available or you need more control:

#### Step 1: Update Version Numbers

Update version in `macos-support-tools.xcodeproj/project.pbxproj`:

```
MARKETING_VERSION = 1.0.0;
CURRENT_PROJECT_VERSION = 1;
```

Or use Xcode:
1. Open project in Xcode
2. Select project in navigator
3. Select target "macos-support-tools"
4. Go to General tab
5. Update Version and Build numbers

#### Step 2: Update CHANGELOG.md

Add a new section at the top:

```markdown
## [1.0.0] - 2025-10-14

### Added
- Feature 1
- Feature 2

### Fixed
- Bug fix 1
```

#### Step 3: Commit Version Changes

```bash
git add .
git commit -m "Bump version to 1.0.0"
git push origin main
```

#### Step 4: Build the Application

On a macOS machine with Xcode:

```bash
xcodebuild clean build \
  -project macos-support-tools.xcodeproj \
  -scheme macos-support-tools \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

#### Step 5: Create Release Archive

```bash
# Find the built app
APP_PATH=$(find ./build/Build/Products/Release -name "*.app" -type d | head -1)

# Create ZIP
cd $(dirname "$APP_PATH")
zip -r "macos-support-tools-1.0.0.zip" "macos-support-tools.app"
```

#### Step 6: Create GitHub Release

1. Go to GitHub repository
2. Click "Releases" → "Draft a new release"
3. Create tag: `v1.0.0`
4. Target: `main`
5. Release title: `macOS Support Tools v1.0.0`
6. Description: Copy from CHANGELOG.md and add:

```markdown
## Installation

1. Download `macos-support-tools-1.0.0.zip`
2. Extract the archive
3. Move `macos-support-tools.app` to your Applications folder
4. Launch the app
5. Grant Accessibility permissions when prompted

## Requirements

- macOS 13.0 or later
- Accessibility permissions required
```

7. Upload the ZIP file
8. Click "Publish release"

#### Step 7: Tag the Release

```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

## Post-Release Tasks

After publishing a release:

- [ ] Test the release download and installation
- [ ] Announce the release (social media, blog, etc.)
- [ ] Update any external documentation
- [ ] Close related issues and milestones
- [ ] Start planning next release

## Release Notes Best Practices

Good release notes should include:

1. **Version and Date**: Clear version number and release date
2. **Summary**: Brief overview of what's new
3. **Breaking Changes**: Highlight any breaking changes prominently
4. **New Features**: List new features with brief descriptions
5. **Bug Fixes**: List fixed bugs
6. **Known Issues**: Document any known issues
7. **Installation Instructions**: Clear steps to install
8. **Upgrade Notes**: Special instructions for upgrading
9. **Credits**: Thank contributors

## Troubleshooting

### Build Fails

- Check Xcode version matches project requirements
- Ensure all dependencies are available
- Clean build folder and try again

### Release Workflow Fails

- Check GitHub Actions logs for errors
- Verify secrets and permissions are configured
- Ensure tag format is correct (v1.0.0)

### App Won't Launch After Installation

- Check code signing requirements
- Verify macOS version compatibility
- Ensure user has granted necessary permissions

## Versioning Examples

- `1.0.0` → `1.0.1`: Bug fixes only
- `1.0.0` → `1.1.0`: New features added
- `1.0.0` → `2.0.0`: Breaking changes
- `1.0.0-beta.1`: Pre-release version

## Support

For questions about the release process, open an issue or contact the maintainers.
