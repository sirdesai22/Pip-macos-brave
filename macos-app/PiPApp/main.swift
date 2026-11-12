import AppKit

// Brave launches native-messaging hosts with the extension origin as the first argument.
// In that case we act as the host (stdin/stdout) and never start the UI.
if CommandLine.arguments.count > 1, CommandLine.arguments[1].hasPrefix("chrome-extension://") {
    NativeHost.run()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // agent app: no Dock icon, no menu bar (also set via LSUIElement)
app.run()
