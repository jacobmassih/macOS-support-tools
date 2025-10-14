# Contributing to macOS Support Tools

Thank you for your interest in contributing to macOS Support Tools! This document provides guidelines for contributing to the project.

## Code of Conduct

Please be respectful and considerate in all interactions with the project and community.

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Description**: A clear and concise description of the bug
- **Steps to Reproduce**: Step-by-step instructions to reproduce the issue
- **Expected Behavior**: What you expected to happen
- **Actual Behavior**: What actually happened
- **Environment**:
  - macOS version
  - App version
  - Xcode version (if building from source)
- **Screenshots**: If applicable, add screenshots to help explain the problem
- **Additional Context**: Any other context about the problem

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Description**: A clear and concise description of the enhancement
- **Use Case**: Explain why this enhancement would be useful
- **Proposed Solution**: Describe how you think it should work
- **Alternatives Considered**: Describe any alternative solutions or features you've considered
- **Additional Context**: Add any other context or screenshots about the feature request

### Pull Requests

1. **Fork the Repository**: Create your own fork of the code
2. **Create a Branch**: Create a branch with a descriptive name
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Make Your Changes**: Make your changes following the guidelines below
4. **Test Your Changes**: Ensure all tests pass and add new tests if needed
5. **Commit Your Changes**: Use clear and meaningful commit messages
   ```bash
   git commit -m 'Add some amazing feature'
   ```
6. **Push to Your Fork**: Push your changes to your fork
   ```bash
   git push origin feature/amazing-feature
   ```
7. **Open a Pull Request**: Open a pull request to the main repository

## Development Setup

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- Git

### Setting Up the Development Environment

1. Clone the repository:
   ```bash
   git clone https://github.com/jacobmassih/macOS-support-tools.git
   cd macOS-support-tools
   ```

2. Open the project in Xcode:
   ```bash
   open macos-support-tools.xcodeproj
   ```

3. Build and run the project (⌘R)

### Running Tests

To run all tests:

```bash
xcodebuild test \
  -project macos-support-tools.xcodeproj \
  -scheme macos-support-tools \
  -destination 'platform=macOS,arch=arm64'
```

Or use Xcode's Test Navigator (⌘6) to run tests interactively.

## Coding Guidelines

### Swift Style Guide

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Keep functions focused and concise
- Add comments for complex logic
- Use SwiftUI best practices

### Code Organization

- Keep related functionality together
- Separate concerns (UI, business logic, data)
- Use proper access control (private, internal, public)
- Follow the existing project structure

### SwiftUI Specific

- Use `@State` for view-local state
- Use `@Observable` for shared state (following the project pattern)
- Keep views small and composable
- Extract complex views into separate files

### Git Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

Examples:
```
Add mouse button configuration UI

Implement configurable actions for mouse buttons 4 and 5.
Fixes #123
```

## Testing

### Writing Tests

- Write unit tests for business logic
- Write UI tests for user interactions
- Follow existing test patterns
- Use descriptive test names
- Test edge cases and error conditions

### Test Coverage

- Aim for good test coverage of new features
- Don't decrease overall test coverage
- Focus on testing critical paths

## Documentation

- Update README.md if your changes affect usage
- Update CHANGELOG.md following [Keep a Changelog](https://keepachangelog.com/) format
- Add inline comments for complex logic
- Update code documentation (doc comments) for public APIs

## Review Process

1. All submissions require review
2. Reviewers may request changes
3. Address review feedback promptly
4. Once approved, a maintainer will merge your PR

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## Questions?

Feel free to open an issue with your question or reach out to the maintainers.

## Recognition

Contributors will be recognized in release notes and the project's contributors list.

---

Thank you for contributing to macOS Support Tools! 🎉
