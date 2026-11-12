import { HOST_NAME, parseOpenRequest, type OpenRequest, type OpenResponse, type TriggerMessage } from './messaging';

// Each request uses one-shot sendNativeMessage: Brave starts the host, it hands the video to the
// app and exits. No long-lived port, so there's no connection to lose when the app quits or
// the service worker is suspended.
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (sender.id !== chrome.runtime.id || !sender.tab) return false;
  const request = parseOpenRequest(message);
  if (!request) {
    sendResponse({ ok: false, error: 'Invalid request' } satisfies OpenResponse);
    return false;
  }
  openInNativeApp(request).then(sendResponse);
  return true; // respond asynchronously
});

async function openInNativeApp(request: OpenRequest): Promise<OpenResponse> {
  try {
    const reply = await chrome.runtime.sendNativeMessage(HOST_NAME, request);
    if (reply?.ok === true) return { ok: true };
    return { ok: false, error: typeof reply?.error === 'string' ? reply.error : 'Unexpected reply from the native app' };
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    return { ok: false, error: `Native app not reachable (${detail}). Run install.sh and restart Brave.` };
  }
}

// Toolbar button: ask the YouTube tab's content script to collect state and open the player.
chrome.action.onClicked.addListener((tab) => {
  if (tab.id === undefined) return;
  chrome.tabs.sendMessage(tab.id, { type: 'trigger' } satisfies TriggerMessage).catch(() => {
    // Not a YouTube tab (no content script there); nothing to do.
  });
});
