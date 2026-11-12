import AppKit

/// The floating player window.
///
/// Why each setting matters for "stay visible over fullscreen apps":
/// - `NSPanel` + `.nonactivatingPanel`: clicking the player doesn't activate our app, so the
///   fullscreen app you're working in keeps focus and its Space doesn't switch away.
/// - `.canJoinAllSpaces`: the window is present on every Space, including fullscreen Spaces.
/// - `.fullScreenAuxiliary`: the window is allowed to sit *inside* another app's fullscreen Space.
///   Without it, macOS keeps the window out of fullscreen Spaces regardless of level.
/// - `level = .floating`: above normal windows within whichever Space is showing.
/// - `hidesOnDeactivate = false`: NSPanel defaults to hiding when the app deactivates.
/// - The app itself is an agent (`LSUIElement`), which is required for the above to work over
///   *other* apps' fullscreen Spaces; a regular Dock app's windows are not admitted there.
final class PiPPanel: NSPanel {
    init() {
        super.init(
            contentRect: Self.defaultFrame(),
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        // `.titled` gives us native rounded corners, shadow and edge resizing; hide the rest of the chrome.
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }

        appearance = NSAppearance(named: .darkAqua)
        backgroundColor = .black
        contentAspectRatio = NSSize(width: 16, height: 9)
        contentMinSize = NSSize(width: 256, height: 144)
    }

    // Borderless/non-activating panels refuse key status by default; we want clicks and
    // YouTube's keyboard shortcuts to reach the web view.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// 480×270 in the bottom-right corner of the screen under the mouse.
    private static func defaultFrame() -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: 480, height: 270)
        return NSRect(x: area.maxX - size.width - 20, y: area.minY + 20, width: size.width, height: size.height)
    }
}
