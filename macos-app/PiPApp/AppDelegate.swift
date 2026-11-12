import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: PiPPanel?
    private var playerView: PlayerView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Development convenience: `BravePiP https://www.youtube.com/watch?v=…`
        for argument in CommandLine.arguments.dropFirst() {
            if let url = URL(string: argument), let request = VideoRequest(url: url) { show(request) }
        }
        // Launched with nothing to play (e.g. double-clicked in Finder): don't linger invisibly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.panel == nil { NSApp.terminate(nil) }
        }
    }

    /// URLs arrive here from the native-messaging host (via Launch Services), whether or not
    /// the app was already running. Only valid YouTube video URLs are accepted.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if let request = VideoRequest(url: url) { show(request) }
        }
    }

    /// One player only: a new request replaces the current video in the existing panel.
    private func show(_ request: VideoRequest) {
        if panel == nil {
            let view = PlayerView()
            let panel = PiPPanel()
            panel.contentView = view
            self.panel = panel
            playerView = view
        }
        playerView?.load(request)
        panel?.orderFrontRegardless()
    }
}
