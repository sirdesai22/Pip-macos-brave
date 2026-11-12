import WebKit

/// Loads the regular YouTube watch page in a WKWebView and uses CSS to strip the page down to the
/// player, so YouTube's own player (seek bar, volume, captions, quality) keeps working.
@MainActor
final class YouTubePlayer: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    enum State: Equatable { case loading, playing, paused, failed(String) }

    let webView: WKWebView
    var onStateChange: ((State) -> Void)?

    // WKWebView's default UA has no "Version/… Safari/…" token and YouTube serves it a degraded page.
    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15"

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = [] // allow autoplay with sound
        configuration.websiteDataStore = .default() // persistent cookies (consent, optional sign-in)
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        configuration.userContentController.add(self, name: "pip")
        webView.navigationDelegate = self
        webView.customUserAgent = Self.userAgent
        webView.underPageBackgroundColor = .black
    }

    func load(_ request: VideoRequest) {
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(
            source: Self.pageScript(startPaused: request.startPaused),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        onStateChange?(.loading)
        webView.load(URLRequest(url: request.watchURL))
    }

    func togglePlayPause() {
        webView.evaluateJavaScript("""
        (() => {
          const p = document.getElementById('movie_player'), v = document.querySelector('#movie_player video');
          if (!v) return;
          if (v.paused) { p && p.playVideo ? p.playVideo() : v.play(); }
          else { p && p.pauseVideo ? p.pauseVideo() : v.pause(); }
        })()
        """)
    }

    // MARK: Page script

    private static func pageScript(startPaused: Bool) -> String {
        """
        (() => {
          if (location.hostname !== 'www.youtube.com' || location.pathname !== '/watch') return;
          const style = document.createElement('style');
          style.textContent = `
            html, body, ytd-app { background: #000 !important; overflow: hidden !important; }
            #masthead-container, #secondary, #below, tp-yt-app-drawer, ytd-mini-guide-renderer,
            #chat, ytd-popup-container > :not(tp-yt-iron-dropdown) { display: none !important; }
            #movie_player {
              position: fixed !important; inset: 0 !important; width: 100vw !important; height: 100vh !important;
              z-index: 2147483646 !important; background: #000 !important;
            }
            #movie_player .html5-video-container { width: 100% !important; height: 100% !important; }
            #movie_player video {
              width: 100% !important; height: 100% !important; left: 0 !important; top: 0 !important;
              object-fit: contain !important;
            }
          `;
          document.documentElement.appendChild(style);

          const post = (state) => window.webkit.messageHandlers.pip.postMessage(state);
          let startPaused = \(startPaused);
          const attach = () => {
            const v = document.querySelector('#movie_player video');
            if (!v) return void setTimeout(attach, 300);
            v.addEventListener('playing', () => {
              if (startPaused) { startPaused = false; v.pause(); return; }
              post('playing');
            });
            v.addEventListener('pause', () => post('paused'));
            v.addEventListener('canplay', () => post(v.paused ? 'paused' : 'playing'));
            window.dispatchEvent(new Event('resize')); // make YouTube re-layout its controls
          };
          attach();
        })();
        """
    }

    // MARK: WKScriptMessageHandler

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.body as? String {
        case "playing": onStateChange?(.playing)
        case "paused": onStateChange?(.paused)
        default: break
        }
    }

    // MARK: WKNavigationDelegate

    /// Keep the top-level page on YouTube (and Google for consent / sign-in). Sub-frames are left alone.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.targetFrame?.isMainFrame == true else { return decisionHandler(.allow) }
        let host = navigationAction.request.url?.host?.lowercased() ?? ""
        let allowed = ["youtube.com", "google.com"].contains { host == $0 || host.hasSuffix("." + $0) }
        decisionHandler(allowed ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    private func fail(_ error: Error) {
        let error = error as NSError
        // Cancelled = superseded by a newer load or blocked by our policy; not worth showing.
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled { return }
        if error.domain == "WebKitErrorDomain" && error.code == 102 { return } // frame load interrupted
        onStateChange?(.failed(error.localizedDescription))
    }
}
