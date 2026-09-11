/* The Temporary conversation: one transcript that reaches no browser store.

   A durable conversation is written through the store chain in
   `conversations.js` -- IndexedDB, then localStorage, then memory. A Temporary
   conversation takes the memory store alone and takes it from the moment it
   opens, so nothing about it is written and then removed: the record never
   exists on disk to be recovered from a quota sweep, a backup, or a second tab.
   The selected-conversation key stays untouched for the same reason, so a
   reload returns to the durable conversation the reader left rather than to an
   id no store answers for.

   The banner renders when the conversation opens rather than when its first
   message lands, because a reader decides what to type from what the page
   already says. `startTemporary()` shows it and every other transition hides
   it, so the mark is a function of the live state rather than of an event
   nobody replays. */

import { $ } from './api.js';

export const temporaryState = { active: false };

export function isTemporary() {
  return temporaryState.active;
}

function memoryStore() {
  const records = new Map();
  return {
    name: 'temporary',
    async list() { return []; },
    async read(id) { return records.get(id) || null; },
    async write(record) { records.set(record.id, record); },
    async remove(id) { records.delete(id); },
    async clear() { records.clear(); }
  };
}

// One store for the life of the tab. A Temporary conversation switched away
// from and back to within one page session reads what it wrote; a reload reads
// nothing, which is the whole claim.
const store = memoryStore();

export function temporaryStore() {
  return store;
}

export function renderTemporaryBanner() {
  const banner = $('#temporary-banner');
  if (banner) banner.hidden = !temporaryState.active;
}

export function startTemporary() {
  temporaryState.active = true;
  renderTemporaryBanner();
}

export function endTemporary() {
  temporaryState.active = false;
  renderTemporaryBanner();
}
