import Foundation

/// Names that keep the Chorus PTT fork apart from the original Chorus app.
///
/// The SwiftData store and TipKit records live under Application Support in a
/// folder chosen by name, not by bundle id, so the fork needs its own names or
/// it would open the original app's data.
enum PTTAppIdentity {
    /// Release builds keep the store in `Application Support/Chorus PTT`.
    static let storeFolder = "Chorus PTT"

    /// Debug builds keep the store in `Application Support/Chorus PTT-debug`.
    static let debugStoreFolder = "Chorus PTT-debug"

    /// The folder the fork's own files (such as the link rules) live in.
    static var supportFolder: URL {
        #if DEBUG
        URL.applicationSupportDirectory.appending(path: debugStoreFolder)
        #else
        URL.applicationSupportDirectory.appending(path: storeFolder)
        #endif
    }
}
