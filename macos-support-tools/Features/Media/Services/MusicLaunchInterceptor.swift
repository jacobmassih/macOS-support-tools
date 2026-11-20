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
    @ObservationIgnored private let center: NotificationCenter
    @ObservationIgnored private let spotifyURL: () -> URL?
    @ObservationIgnored private let openSpotify: (URL, @escaping (Bool) -> Void) -> Void
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(
        userDefaults: UserDefaults = .standard,
        center: NotificationCenter = NSWorkspace.shared.notificationCenter,
        spotifyURL: @escaping () -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: MediaBundleID.spotify)
        },
        openSpotify: @escaping (URL, @escaping (Bool) -> Void) -> Void = { url, completion in
            NSWorkspace.shared.openApplication(at: url, configuration: .init()) { application, error in
                DispatchQueue.main.async { completion(application != nil && error == nil) }
            }
        }
    ) {
        self.userDefaults = userDefaults
        self.center = center
        self.spotifyURL = spotifyURL
        self.openSpotify = openSpotify

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
        isSpotifyInstalled = spotifyURL() != nil
    }

    private func startObserving() {
        guard observer == nil else { return }
        refreshSpotifyInstalled()

        observer = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleLaunch(notification)
        }
    }

    private func stopObserving() {
        if let observer {
            center.removeObserver(observer)
            self.observer = nil
        }
    }

    private func handleLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication else {
            return
        }

        handleLaunch(bundleID: app.bundleIdentifier) { _ = app.terminate() }
    }

    func handleLaunch(bundleID: String?, terminateMusic: @escaping () -> Void) {
        guard bundleID == MediaBundleID.appleMusic else { return }
        let url = spotifyURL()
        isSpotifyInstalled = url != nil
        guard MusicLaunchInterceptorCore.action(
            forLaunchedBundleID: bundleID,
            isEnabled: isEnabled,
            isSpotifyInstalled: isSpotifyInstalled
        ) == .redirectToSpotify, let url, let launchObserver = observer else { return }

        openSpotify(url) { [weak self] opened in
            if opened && self?.observer === launchObserver {
                terminateMusic()
            }
        }
    }
}
