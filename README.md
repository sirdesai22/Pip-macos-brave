# BravePiP

A native macOS floating player for YouTube videos from Brave. It stays visible above other apps, including apps in fullscreen, and on every Space.

Click **Open in Native PiP** in YouTube's player controls (or the extension's toolbar button). The video continues in a small native window at the same position, and the Brave tab pauses.

```
brave-extension/        MV3 extension (TypeScript)
  src/content.ts        button in YouTube's player, collects video id / time / paused state
  src/background.ts     forwards requests to the native host (chrome.runtime.sendNativeMessage)
  src/messaging.ts      shared types + validation
macos-app/              Swift / AppKit, built with swiftc (no Xcode project needed)
  PiPApp/               entry point (app mode vs native-messaging host mode), AppDelegate
  WindowManager/        PiPPanel: the floating NSPanel
  Views/                PlayerView: web view, spinner, error text, hover control bar
  Browser/              YouTubePlayer: WKWebView that loads the YouTube watch page
  Messaging/            NativeHost (stdin/stdout protocol), VideoRequest (validation)
  Resources/Info.plist
install.sh              builds everything, installs the app, registers the host with Brave
```

## Install

Requirements: macOS 13+, Xcode Command Line Tools (`xcode-select --install`), Node 18+.

```bash
./install.sh
```

The script:
1. Builds `BravePiP.app` and copies it to `~/Applications/BravePiP.app`.
2. Builds the extension into `brave-extension/dist/`.
3. Writes the Native Messaging host manifest `com.bravepip.host.json`, allowing only this extension's ID, to two folders:
   - `~/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts/`, Brave's documented location.
   - `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/`, which is where Brave 1.97 actually looks.

Then load the extension:
1. Open `brave://extensions`.
2. Turn on **Developer mode** (top right).
3. Click **Load unpacked** and select the `brave-extension` folder.
4. Check that the ID is `odcmmleffipgcmgkgokfdabcjihjnpln`. The `key` in `manifest.json` keeps this ID the same on every machine, so the host manifest always matches.
5. Reload any YouTube tabs that were already open.

Re-run `./install.sh` after changing code. After changing the extension, also click the reload icon on its card in `brave://extensions`.

Uninstall:

```bash
rm -rf ~/Applications/BravePiP.app \
  "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.bravepip.host.json" \
  "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.bravepip.host.json"
```

## Using it

- **Open**: click the PiP icon in YouTube's player controls, or the extension's toolbar button, on a `youtube.com/watch` or `/shorts/` page.
- **Move**: hover the player and drag the top bar.
- **Resize**: drag any edge or corner. The window keeps a 16:9 ratio.
- **Play/pause, close**: buttons in the top bar. YouTube's own controls (seek, volume, captions, quality) also work.
- Opening another video replaces the one in the player. There is only ever one player.
- Closing the player quits the app. Brave starts it again on the next request.

For development you can run the player without Brave:

```bash
macos-app/build.sh && macos-app/build/BravePiP.app/Contents/MacOS/BravePiP 'https://www.youtube.com/watch?v=aqz-KE-bpKQ&t=60'
```

## How it works

```
YouTube tab ──content script──▶ background worker ──sendNativeMessage──▶ BravePiP (host mode)
                                                                            │ validates, then
                                                                            ▼ NSWorkspace.open(url, withApplicationAt: own bundle)
                                                                       BravePiP.app (player) ── WKWebView
```

- **One binary, two modes.** Brave starts native-messaging hosts with `chrome-extension://<id>/` as the first argument. When `main.swift` sees that argument, it runs `NativeHost`: it reads one length-prefixed JSON message, validates it, replies, and exits. It never starts any UI.
- **Handing off to the player.** Brave kills the host process when messaging ends, so the host doesn't play anything itself. It asks Launch Services to open a rebuilt `https://www.youtube.com/watch?v=…` URL in its own bundle. Launch Services either starts the app as an independent process or delivers the URL to the running instance (`application(_:open:)`). This guarantees a single player. No custom URL scheme is registered, so web pages can't trigger the app.
- **One-shot messaging.** Each click uses `sendNativeMessage` and starts a short-lived host. There's no long-lived port, so nothing breaks when the app quits, Brave's service worker is suspended, or the extension reloads.
- **Validation.** Video IDs must match `[A-Za-z0-9_-]{11}`, which is checked in both the extension and Swift. Time is clamped and the message size is capped. The app only ever builds `https://www.youtube.com/watch?v=<id>&t=<n>s` itself. The web view's top-level page can only go to `youtube.com` / `google.com` (consent and sign-in), and popups are blocked. Nothing is executed from a message.

### Window behaviour (the important part)

`WindowManager/PiPPanel.swift`:

| Setting | Why |
|---|---|
| `NSPanel` with `.nonactivatingPanel` | Clicking the player doesn't activate BravePiP, so focus and the current fullscreen Space stay with the app you're working in. |
| `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` | `.canJoinAllSpaces` puts the window on every Space. `.fullScreenAuxiliary` allows it inside another app's fullscreen Space. Without this, `.floating` alone does **not** show over fullscreen apps. |
| `level = .floating` | Above normal windows in whichever Space is showing. |
| `hidesOnDeactivate = false` | NSPanel's default hides the panel when its app isn't active, which is almost always for this app. |
| `LSUIElement` + `.accessory` activation policy | An agent app with no Dock icon or menu bar. Windows of regular (Dock) apps aren't admitted into other apps' fullscreen Spaces even with the flags above. |
| `.titled` + `.fullSizeContentView` with a hidden, transparent title bar | Native rounded corners, shadow and edge resizing, but no visible chrome. |
| `canBecomeKey = true` | Clicks and YouTube keyboard shortcuts reach the web view. |

### Playback

The player loads the normal YouTube watch page (`&t=<seconds>s` for the start position) with a Safari user agent. WKWebView's default user agent gets a degraded page. Injected CSS pins `#movie_player` to the full window and hides the rest of the page, so YouTube's own player still handles seeking, captions, quality and ads. A small injected script reports play/pause state to Swift for the button icon and the loading spinner, and pauses at start if the Brave video was paused. Media streams are never extracted or downloaded.

## What was tested (macOS 26.4, Brave 1.97)

Verified:
- The panel stays on screen inside **another app's fullscreen Space**. A regular app window was put into native fullscreen, and the window server's on-screen list still included the BravePiP panel at the floating level. The Space really did switch, because the other windows dropped off the list.
- The panel stays on screen when other apps come to the front.
- YouTube loads and fills the panel. Start time and paused state are respected, play/pause works, and resizing re-lays out the video and YouTube's controls.
- Host protocol: valid requests launch the player, while invalid IDs, wrong message types and non-JSON input are rejected with an error reply.
- End to end in Brave, with the unpacked extension in a throwaway profile:
  - the button appears in YouTube's controls;
  - clicking it sends `{videoId, time: 95, paused: false}` and the native player opens;
  - the Brave tab pauses;
  - a second click reuses the same single player;
  - if the host is missing, the tab shows a clear error.

Not yet verified (needs manual checks):
- Fullscreen **VS Code, Safari and Terminal** specifically. Scripting those apps into fullscreen needs Accessibility permission, which the test environment didn't have. The same macOS mechanism was tested with a real fullscreen app window, but please check these apps by hand.
- Switching between several desktop Spaces with Ctrl+←/→.
- Dragging, edge-resizing and the close button with a real mouse. The underlying calls were tested, but the hover bar wasn't clicked.
- Your normal Brave profile. On the first install it didn't find the host in Brave's folder, so the installer now also writes to Chrome's folder (see Troubleshooting).

## Limitations

The player is a **separate WKWebView session**, not your Brave session:
- You aren't signed in to YouTube in it. No Premium, so expect **ads**. Members-only, private and some age-restricted videos won't play. Watch history and recommendations aren't shared with Brave. Cookies persist in the app's own WebKit store (`~/Library/WebKit/com.bravepip.app`), so consent choices are remembered.
- Brave Shields don't apply inside the player.
- It depends on YouTube's page structure (`#movie_player`, `.ytp-right-controls`). If YouTube changes those, the CSS or the injected button may need updating. The toolbar button still works if the in-player button disappears.
- YouTube's own fullscreen button inside the player does nothing, because element fullscreen is disabled.
- Shorts open in the 16:9 player with black bars on the sides.
- Apple Silicon/Intel builds are for the machine you build on. The app is ad-hoc signed for local use, not notarized.

## Troubleshooting

- **"Native app not reachable (Specified native messaging host not found)"**: run `./install.sh`, then quit and restart Brave completely. Brave 1.97 looks for the host manifest in Chrome's `NativeMessagingHosts` folder, not in Brave's own, and the installer writes to both.
- **"Access to the specified native messaging host is forbidden"**: the extension ID doesn't match `allowed_origins`. Make sure `manifest.json` still has its `key`, then re-run `./install.sh`.
- **No button in the player**: reload the YouTube tab after loading or reloading the extension.
