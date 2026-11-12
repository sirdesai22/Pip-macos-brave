import AppKit

/// Chrome Native Messaging host mode.
///
/// Brave runs this same executable with the extension origin (`chrome-extension://<id>/`) as the
/// first argument, writes one message (4-byte native-endian length + UTF-8 JSON) to stdin and waits
/// for one reply in the same framing on stdout.
///
/// The host does not play anything itself: Brave kills the host when messaging ends, so it validates
/// the request and asks Launch Services to open the URL in the app bundle. Launch Services starts the
/// app if needed (outside Brave's process tree) or delivers the URL to the already-running instance,
/// which also guarantees a single player process.
enum NativeHost {
    struct HostError: Error { let message: String }

    static func run() -> Never {
        var reply: [String: Any] = ["ok": true]
        do {
            try openPlayer(with: readRequest())
        } catch let error as HostError {
            reply = ["ok": false, "error": error.message]
        } catch {
            reply = ["ok": false, "error": error.localizedDescription]
        }
        write(reply)
        exit(0)
    }

    private static func readRequest() throws -> VideoRequest {
        let stdin = FileHandle.standardInput
        guard let header = try stdin.read(upToCount: 4), header.count == 4 else {
            throw HostError(message: "No message received")
        }
        let length = Int(header.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        guard length > 0, length <= 4096,
              let body = try stdin.read(upToCount: length), body.count == length,
              let json = try JSONSerialization.jsonObject(with: body) as? [String: Any],
              json["type"] as? String == "open",
              let videoId = json["videoId"] as? String,
              let request = VideoRequest(
                  videoId: videoId,
                  startTime: json["time"] as? Double ?? 0,
                  startPaused: json["paused"] as? Bool ?? false
              )
        else {
            throw HostError(message: "Invalid request")
        }
        return request
    }

    private static func openPlayer(with request: VideoRequest) throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        let done = DispatchSemaphore(value: 0)
        var failure: Error?
        NSWorkspace.shared.open([request.handoffURL], withApplicationAt: Bundle.main.bundleURL, configuration: configuration) { _, error in
            failure = error
            done.signal()
        }
        if done.wait(timeout: .now() + 10) == .timedOut { throw HostError(message: "Timed out launching player") }
        if let failure { throw HostError(message: failure.localizedDescription) }
    }

    private static func write(_ object: [String: Any]) {
        let data = (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
        var length = UInt32(data.count)
        FileHandle.standardOutput.write(Data(bytes: &length, count: 4))
        FileHandle.standardOutput.write(data)
    }
}
