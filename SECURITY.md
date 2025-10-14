# Security Policy

## Supported Versions

Currently supported versions of macOS Support Tools:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in macOS Support Tools, please follow these steps:

1. **Do Not** disclose the vulnerability publicly until it has been addressed
2. Email the maintainer with details about the vulnerability
3. Include steps to reproduce the issue if possible
4. Allow reasonable time for the issue to be addressed before public disclosure

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if you have one)

## Security Considerations

### Permissions Required

This application requires the following permissions:

- **Accessibility**: Required to intercept and modify mouse events
- **Input Monitoring**: Required to detect mouse button presses

### Privacy

- No data is collected or transmitted to external servers
- All settings are stored locally using UserDefaults
- Device information is only used for device identification and settings persistence

### Code Signing

Official releases are built and distributed through GitHub releases. While the app can be built from source, please verify the authenticity of any binary you download.

## Best Practices for Users

1. Only download releases from the official GitHub repository
2. Verify checksums of downloaded files if provided
3. Review the source code before building from source
4. Keep your macOS system updated with the latest security patches
5. Only grant the minimum permissions required for the app to function

## Response Timeline

- Critical vulnerabilities: 48 hours
- High severity: 7 days
- Medium/Low severity: 30 days

Thank you for helping keep macOS Support Tools and its users safe!
