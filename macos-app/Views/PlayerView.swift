import AppKit

/// Panel content: the web player, a loading spinner / error label, and a control bar that
/// fades in while the mouse is over the window.
final class PlayerView: NSView {
    private let player = YouTubePlayer()
    private let bar = ControlBar()
    private let spinner = NSProgressIndicator()
    private let message = NSTextField(wrappingLabelWithString: "")

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        let web = player.webView
        for view in [web, spinner, message, bar] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: leadingAnchor),
            web.trailingAnchor.constraint(equalTo: trailingAnchor),
            web.topAnchor.constraint(equalTo: topAnchor),
            web.bottomAnchor.constraint(equalTo: bottomAnchor),

            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.heightAnchor.constraint(equalToConstant: 32),

            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),

            message.centerXAnchor.constraint(equalTo: centerXAnchor),
            message.centerYAnchor.constraint(equalTo: centerYAnchor),
            message.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -40),
        ])

        spinner.style = .spinning
        spinner.isDisplayedWhenStopped = false
        message.alignment = .center
        message.textColor = .secondaryLabelColor
        message.isHidden = true
        bar.alphaValue = 0

        bar.onClose = { NSApp.terminate(nil) }
        bar.onPlayPause = { [weak self] in self?.player.togglePlayPause() }
        player.onStateChange = { [weak self] in self?.apply($0) }

        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func load(_ request: VideoRequest) {
        player.load(request)
    }

    private func apply(_ state: YouTubePlayer.State) {
        switch state {
        case .loading:
            message.isHidden = true
            spinner.startAnimation(nil)
        case .playing, .paused:
            spinner.stopAnimation(nil)
            bar.isPlaying = state == .playing
        case .failed(let text):
            spinner.stopAnimation(nil)
            message.stringValue = "Couldn't load the video.\n\(text)"
            message.isHidden = false
        }
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { _ in bar.animator().alphaValue = 1 }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { _ in bar.animator().alphaValue = 0 }
    }
}

/// Top strip: drag handle for the window plus close and play/pause buttons.
final class ControlBar: NSView {
    var onClose: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var isPlaying = false {
        didSet { playButton.image = Self.symbol(isPlaying ? "pause.fill" : "play.fill") }
    }

    private lazy var closeButton = makeButton("xmark", label: "Close", action: #selector(close))
    private lazy var playButton = makeButton("play.fill", label: "Play/Pause", action: #selector(playPause))

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor

        let stack = NSStackView(views: [closeButton, playButton])
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @objc private func close() { onClose?() }
    @objc private func playPause() { onPlayPause?() }

    private func makeButton(_ symbol: String, label: String, action: Selector) -> NSButton {
        let button = NSButton(image: Self.symbol(symbol), target: self, action: action)
        button.isBordered = false
        button.contentTintColor = .white
        button.setAccessibilityLabel(label)
        button.toolTip = label
        button.widthAnchor.constraint(equalToConstant: 22).isActive = true
        return button
    }

    private static func symbol(_ name: String) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
    }
}
