import Foundation

/// Bundle identifiers involved in the Apple Music -> Spotify redirect.
enum MediaBundleID {
    static let appleMusic = "com.apple.Music"
    static let spotify = "com.spotify.client"
}

/// The action the interceptor should take in response to an application launch.
///
/// This is a pure, side-effect-free decision so it can be unit tested without
/// touching AppKit or `NSWorkspace`.
enum MusicLaunchAction: Equatable {
    /// Do nothing; the launch is not something we intercept.
    case ignore
    /// Terminate the launching app (Apple Music) and open Spotify.
    case redirectToSpotify
}

/// Pure decision-making core for the Music -> Spotify redirect feature.
///
/// The core deliberately has no dependency on `NSWorkspace` or any running
/// application object. Callers feed it the relevant facts (feature enabled,
/// which app launched, whether Spotify is installed) and it returns the action
/// to perform. A thin AppKit adapter (`MusicLaunchInterceptor`) applies it.
enum MusicLaunchInterceptorCore {
    /// Decide how to react to an application launch notification.
    ///
    /// - Parameters:
    ///   - launchedBundleID: The bundle identifier of the app that just launched.
    ///   - isEnabled: Whether the redirect feature is currently enabled.
    ///   - isSpotifyInstalled: Whether Spotify is installed on the machine.
    /// - Returns: The action the adapter should perform.
    static func action(
        forLaunchedBundleID launchedBundleID: String?,
        isEnabled: Bool,
        isSpotifyInstalled: Bool
    ) -> MusicLaunchAction {
        guard isEnabled else { return .ignore }
        guard launchedBundleID == MediaBundleID.appleMusic else { return .ignore }
        // Never kill Music if we have nowhere to redirect to.
        guard isSpotifyInstalled else { return .ignore }
        return .redirectToSpotify
    }
}
