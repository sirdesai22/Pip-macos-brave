import Foundation

/// A validated request to play one YouTube video. Every input (native message, launch URL,
/// command-line argument) is turned into one of these before anything is loaded.
struct VideoRequest: Equatable {
    let videoId: String
    let startTime: Int // seconds
    let startPaused: Bool

    init?(videoId: String, startTime: Double = 0, startPaused: Bool = false) {
        guard Self.isValidId(videoId), startTime.isFinite else { return nil }
        self.videoId = videoId
        self.startTime = max(0, min(Int(startTime), 7 * 24 * 3600))
        self.startPaused = startPaused
    }

    /// YouTube video IDs are exactly 11 characters of [A-Za-z0-9_-].
    static func isValidId(_ id: String) -> Bool {
        id.utf8.count == 11 && id.utf8.allSatisfy { c in
            (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x2D || c == 0x5F
        }
    }

    /// Accepts https youtube.com/watch?v=…, youtube.com/shorts/…, youtu.be/… (plus our `pip_paused` flag).
    init?(url: URL) {
        guard url.scheme == "https", let host = url.host?.lowercased(),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let query = components.queryItems ?? []
        func item(_ name: String) -> String? { query.first { $0.name == name }?.value }

        var id: String?
        if ["www.youtube.com", "youtube.com", "m.youtube.com"].contains(host) {
            if url.path == "/watch" {
                id = item("v")
            } else if url.path.hasPrefix("/shorts/") {
                id = url.pathComponents.dropFirst(2).first
            }
        } else if host == "youtu.be" {
            id = url.pathComponents.dropFirst().first
        }
        let time = Double(item("t")?.trimmingCharacters(in: CharacterSet(charactersIn: "s")) ?? "") ?? 0
        self.init(videoId: id ?? "", startTime: time, startPaused: item("pip_paused") == "1")
    }

    /// The page the player loads.
    var watchURL: URL {
        var components = URLComponents(string: "https://www.youtube.com/watch")!
        components.queryItems = [URLQueryItem(name: "v", value: videoId)]
        if startTime > 0 { components.queryItems!.append(URLQueryItem(name: "t", value: "\(startTime)s")) }
        return components.url!
    }

    /// The URL the native-messaging host hands to the app via Launch Services.
    var handoffURL: URL {
        var components = URLComponents(url: watchURL, resolvingAgainstBaseURL: false)!
        if startPaused { components.queryItems!.append(URLQueryItem(name: "pip_paused", value: "1")) }
        return components.url!
    }
}
