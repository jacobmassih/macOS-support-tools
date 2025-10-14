# Release Checklist

Use this checklist when preparing a new release of macOS Support Tools.

## Pre-Release

### Code & Tests
- [ ] All planned features are implemented and merged
- [ ] All tests pass locally
- [ ] CI/CD pipeline passes (GitHub Actions)
- [ ] No critical bugs or regressions
- [ ] Code reviewed and approved

### Version & Documentation
- [ ] Version number updated in Xcode project (`MARKETING_VERSION`)
- [ ] Build number updated if needed (`CURRENT_PROJECT_VERSION`)
- [ ] CHANGELOG.md updated with new version section
- [ ] All changes documented in CHANGELOG.md
- [ ] README.md updated if features changed
- [ ] Documentation updated (if needed)
- [ ] Breaking changes clearly documented

### Quality Checks
- [ ] Manual testing completed on target macOS versions
- [ ] Tested with different mouse models
- [ ] Permissions work correctly
- [ ] Launch at login works
- [ ] Settings persist correctly
- [ ] No console errors or warnings
- [ ] Memory leaks checked
- [ ] Performance acceptable

## Release Process

### Prepare Repository
- [ ] Create release branch (optional): `release/v1.x.x`
- [ ] Commit version changes
- [ ] Push to GitHub
- [ ] Create PR if using release branch
- [ ] Get PR approved and merge to main

### Create Release

#### Automated Method (Recommended)
- [ ] Checkout main branch: `git checkout main`
- [ ] Pull latest changes: `git pull origin main`
- [ ] Create tag: `git tag -a v1.x.x -m "Release version 1.x.x"`
- [ ] Push tag: `git push origin v1.x.x`
- [ ] Verify GitHub Actions workflow starts
- [ ] Monitor workflow progress
- [ ] Verify workflow completes successfully

#### Manual Method (If needed)
- [ ] Build app locally with Release configuration
- [ ] Run tests
- [ ] Create ZIP archive
- [ ] Write release notes (use CHANGELOG.md)
- [ ] Create GitHub release
- [ ] Upload ZIP file
- [ ] Publish release

### Verify Release
- [ ] Release appears on GitHub releases page
- [ ] Assets are downloadable
- [ ] ZIP file extracts correctly
- [ ] App launches on clean system
- [ ] Version number is correct in app
- [ ] Release notes are correct
- [ ] Links in release notes work

## Post-Release

### Testing
- [ ] Download release from GitHub
- [ ] Test installation on clean macOS system
- [ ] Verify all features work
- [ ] Check permissions prompt appears
- [ ] Test with multiple mouse models
- [ ] Verify settings persistence

### Communication
- [ ] Update project website (if applicable)
- [ ] Post announcement (social media, blog, etc.)
- [ ] Notify users of the release
- [ ] Close milestone (if using)
- [ ] Close related issues

### Maintenance
- [ ] Monitor for bug reports
- [ ] Check GitHub issues
- [ ] Respond to user questions
- [ ] Track download statistics
- [ ] Plan next release

## Rollback Plan

If critical issues are found:

### Immediate Actions
- [ ] Remove release or mark as pre-release
- [ ] Document the issue
- [ ] Notify users if they downloaded it
- [ ] Create hotfix branch

### Fix and Re-release
- [ ] Fix the critical issue
- [ ] Test thoroughly
- [ ] Increment patch version (e.g., 1.0.0 → 1.0.1)
- [ ] Follow release process again

## Version Types

### Patch Release (1.0.0 → 1.0.1)
- Bug fixes only
- No new features
- No breaking changes
- Minimal testing required
- Quick turnaround

### Minor Release (1.0.0 → 1.1.0)
- New features
- Bug fixes
- No breaking changes
- Moderate testing required
- Standard process

### Major Release (1.0.0 → 2.0.0)
- Breaking changes
- Major new features
- Significant refactoring
- Extensive testing required
- Migration guide needed

## Useful Commands

### Version Management
```bash
# Check current version
grep MARKETING_VERSION macos-support-tools.xcodeproj/project.pbxproj

# View tags
git tag -l

# Delete local tag
git tag -d v1.x.x

# Delete remote tag
git push origin :refs/tags/v1.x.x
```

### Build Commands
```bash
# Clean build
xcodebuild clean

# Build for release
xcodebuild build -project macos-support-tools.xcodeproj \
  -scheme macos-support-tools \
  -configuration Release

# Run tests
xcodebuild test -project macos-support-tools.xcodeproj \
  -scheme macos-support-tools \
  -destination 'platform=macOS,arch=arm64'
```

### Release Artifact
```bash
# Find built app
find ~/Library/Developer/Xcode/DerivedData -name "*.app" -path "*/Release/*"

# Create ZIP
cd path/to/app/directory
zip -r macos-support-tools-v1.x.x.zip macos-support-tools.app
```

## Timeline Estimates

### Patch Release
- Preparation: 1-2 hours
- Testing: 2-3 hours
- Release: 30 minutes
- **Total: 4-6 hours**

### Minor Release
- Preparation: 2-4 hours
- Testing: 4-6 hours
- Release: 1 hour
- **Total: 7-11 hours**

### Major Release
- Preparation: 1-2 days
- Testing: 2-3 days
- Release: 2-3 hours
- **Total: 3-5 days**

## Emergency Release

For critical security or crash bugs:

1. **Immediate** (< 1 hour)
   - [ ] Assess severity
   - [ ] Create hotfix branch
   - [ ] Develop fix
   
2. **Testing** (1-2 hours)
   - [ ] Test fix thoroughly
   - [ ] Verify no new issues
   
3. **Release** (30 minutes)
   - [ ] Skip normal process steps if needed
   - [ ] Fast-track approval
   - [ ] Immediate release
   
4. **Communication** (Ongoing)
   - [ ] Notify users immediately
   - [ ] Explain the issue and fix
   - [ ] Provide upgrade instructions

## Notes

- Always test on a clean macOS installation
- Keep release notes clear and user-friendly
- Document breaking changes prominently
- Thank contributors in release notes
- Archive build artifacts for reference
- Update this checklist as process improves

---

Last updated: 2025-10-14
