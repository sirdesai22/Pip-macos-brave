// Shared message types and validation for content script ⇄ background ⇄ native host.

/** Must match the "name" in the native messaging host manifest written by install.sh. */
export const HOST_NAME = 'com.bravepip.host';

/** Content script → background → native host. */
export interface OpenRequest {
  type: 'open';
  videoId: string;
  time: number; // seconds
  paused: boolean;
}

export type OpenResponse = { ok: true } | { ok: false; error: string };

/** Background → content script, when the toolbar button is clicked. */
export interface TriggerMessage {
  type: 'trigger';
}

const VIDEO_ID = /^[A-Za-z0-9_-]{11}$/;

/** Returns a sanitized request, or null if the message isn't a valid open request. */
export function parseOpenRequest(message: unknown): OpenRequest | null {
  if (typeof message !== 'object' || message === null) return null;
  const m = message as Record<string, unknown>;
  if (m.type !== 'open' || typeof m.videoId !== 'string' || !VIDEO_ID.test(m.videoId)) return null;
  const time = typeof m.time === 'number' && Number.isFinite(m.time) && m.time > 0 ? Math.floor(m.time) : 0;
  return { type: 'open', videoId: m.videoId, time, paused: m.paused === true };
}

/** Video ID for youtube.com/watch?v=… and youtube.com/shorts/… pages. */
export function videoIdFromUrl(href: string): string | null {
  let url: URL;
  try {
    url = new URL(href);
  } catch {
    return null;
  }
  if (url.hostname !== 'www.youtube.com') return null;
  const id =
    url.pathname === '/watch'
      ? url.searchParams.get('v')
      : url.pathname.startsWith('/shorts/')
        ? url.pathname.split('/')[2]
        : null;
  return id && VIDEO_ID.test(id) ? id : null;
}
