import Foundation
import AppKit
import Observation

/// Redirects Apple Music launches to Spotify.
///
/// When enabled, this observes `NSWorkspace` application-launch notifications.
/// If Apple Music (`com.apple.Music`) launches — typically because macOS's `rcd`
/// daemon reacted to a Bluetooth earphone play/pause or a remapped media key — it
/// terminates Music and opens Spotify instead. This mirrors the noTunes approach
/// of intercepting the launch via `NSWorkspace` rather than trying to capture the
/// AVRCP media command (which never reaches a `CGEventTap`).
///
/// Decision-making lives in `MusicLaunchInterceptorCore` so it can be unit tested
/// without AppKit side effects; this class is the thin adapter that applies the
/// decision to the real workspace.
@Observable class MusicLaunchInterceptor {
    enum DefaultsKey {
        static let isEnabled = "MusicRedirectEnabled"
    }

    /// Whether the redirect is active. Persisted to `UserDefaults` (default OFF).
    var isEnabled = false {
        didSet {
            guard oldValue != isEnabled else { return }
            userDefaults.set(isEnabled, forKey: DefaultsKey.isEnabled)
            if isEnabled {
                startObserving()
            } else {
                stopObserving()
            }
        }
    }

    /// Whether Spotify is currently installed. Surfaced in the settings UI.
    private(set) var isSpotifyInstalled = false

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let workspace: NSWorkspace
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(userDefaults: UserDefaults = .standard, workspace: NSWorkspace = .shared) {
        self.userDefaults = userDefaults
        self.workspace = workspace

        userDefaults.register(defaults: [DefaultsKey.isEnabled: false])
        isEnabled = userDefaults.bool(forKey: DefaultsKey.isEnabled)
        refreshSpotifyInstalled()

        if isEnabled {
            startObserving()
        }
    }

    deinit {
        stopObserving()
    }

    /// Re-check whether Spotify is installed (e.g. when the settings window appears).
    func refreshSpotifyInstalled() {
        isSpotifyInstalled = workspace.urlForApplication(
            withBundleIdentifier: MediaBundleID.spotify
        ) != nil
    }

    private func startObserving() {
        guard observer == nil else { return }
        refreshSpotifyInstalled()

        observer = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleLaunch(notification)
        }
    }

    private func stopObserving() {
        if let observer {
            workspace.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }

    private func handleLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication else {
            return
        }

        refreshSpotifyInstalled()

        let decision = MusicLaunchInterceptorCore.action(
            forLaunchedBundleID: app.bundleIdentifier,
            isEnabled: isEnabled,
            isSpotifyInstalled: isSpotifyInstalled
        )

        guard decision == .redirectToSpotify else { return }

        // Kill the freshly launched Music, preferring a graceful terminate.
        if !app.terminate() {
            app.forceTerminate()
        }
        launchSpotify()
    }

    private func launchSpotify() {
        guard let spotifyURL = workspace.urlForApplication(
            withBundleIdentifier: MediaBundleID.spotify
        ) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.openApplication(at: spotifyURL, configuration: configuration)
    }
}
