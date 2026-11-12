import { videoIdFromUrl, type OpenRequest, type OpenResponse } from './messaging';

const BUTTON_ID = 'native-pip-button';

function currentVideo(): HTMLVideoElement | null {
  return document.querySelector<HTMLVideoElement>('#movie_player video') ?? document.querySelector('video');
}

async function openInNativePiP(): Promise<void> {
  const videoId = videoIdFromUrl(location.href);
  if (!videoId) return toast('Open a YouTube video first.');

  const video = currentVideo();
  const request: OpenRequest = {
    type: 'open',
    videoId,
    time: video?.currentTime ?? 0,
    paused: video?.paused ?? false,
  };

  let response: OpenResponse | undefined;
  try {
    response = await chrome.runtime.sendMessage(request);
  } catch {
    response = { ok: false, error: 'The extension was reloaded. Refresh this tab.' };
  }

  if (response?.ok) {
    video?.pause(); // playback continues in the native player
  } else {
    toast(`Native PiP: ${response?.error ?? 'unknown error'}`);
  }
}

// "Open in Native PiP" button in YouTube's player controls. YouTube is a single-page app that
// rebuilds parts of the player, so re-check cheaply instead of observing the whole DOM.
function ensureButton(): void {
  if (document.getElementById(BUTTON_ID)) return;
  const controls = document.querySelector('#movie_player .ytp-right-controls');
  if (!controls) return;

  const button = document.createElement('button');
  button.id = BUTTON_ID;
  button.className = 'ytp-button';
  button.title = 'Open in Native PiP';
  button.setAttribute('aria-label', 'Open in Native PiP');
  button.append(pipIcon());
  button.addEventListener('click', (event) => {
    event.stopPropagation();
    void openInNativePiP();
  });
  controls.prepend(button);
}

function pipIcon(): SVGSVGElement {
  // Built with DOM APIs: YouTube enforces Trusted Types, so innerHTML is off-limits.
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('viewBox', '-6 -6 36 36');
  svg.setAttribute('width', '100%');
  svg.setAttribute('height', '100%');
  const path = document.createElementNS(ns, 'path');
  path.setAttribute('fill', '#fff');
  path.setAttribute(
    'd',
    'M19 11h-8v6h8v-6zm4 8V4.98C23 3.88 22.1 3 21 3H3c-1.1 0-2 .88-2 1.98V19c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2zm-2 .02H3V4.97h18v14.05z',
  );
  svg.append(path);
  return svg;
}

function toast(text: string): void {
  const el = document.createElement('div');
  el.textContent = text;
  Object.assign(el.style, {
    position: 'fixed',
    bottom: '24px',
    left: '50%',
    transform: 'translateX(-50%)',
    zIndex: '2147483647',
    background: 'rgba(0,0,0,.85)',
    color: '#fff',
    padding: '10px 16px',
    borderRadius: '8px',
    font: '14px system-ui, sans-serif',
    maxWidth: '80vw',
  });
  document.body.append(el);
  setTimeout(() => el.remove(), 5000);
}

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type === 'trigger') void openInNativePiP();
});

ensureButton();
setInterval(ensureButton, 1500);
