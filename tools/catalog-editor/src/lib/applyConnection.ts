import type { ActionsFile } from '../types';
import { parseNodeId } from './buildGraph';

// Translates a React Flow edge create/delete into a catalog mutation.
// Returns the next ActionsFile (immutably) or null if no change applies.
//
// Supported connections (bi-directional where it makes sense):
//   phase ↔ action  → adds/removes phase id in action.phases
//   action → school → sets / clears action.sets_school
//   action → picker → sets / clears action.opens_picker
// Other directions are ignored.

export function applyConnect(
  actions: ActionsFile,
  source: string,
  target: string,
): ActionsFile | null {
  const s = parseNodeId(source);
  const t = parseNodeId(target);
  if (!s || !t) return null;

  // Action ↔ Phase
  if ((s.kind === 'phase' && t.kind === 'action') || (s.kind === 'action' && t.kind === 'phase')) {
    const actionId = s.kind === 'action' ? s.id : t.id;
    const phaseId = s.kind === 'phase' ? s.id : t.id;
    const entry = actions.catalog[actionId];
    if (!entry) return null;
    if ((entry.phases ?? []).includes(phaseId)) return null;
    return {
      ...actions,
      catalog: {
        ...actions.catalog,
        [actionId]: { ...entry, phases: [...(entry.phases ?? []), phaseId] },
      },
    };
  }

  // Action → School (sets_school)
  if (s.kind === 'action' && t.kind === 'school') {
    const entry = actions.catalog[s.id];
    if (!entry) return null;
    if (entry.sets_school === t.id) return null;
    return {
      ...actions,
      catalog: { ...actions.catalog, [s.id]: { ...entry, sets_school: t.id } },
    };
  }

  // Action → Picker (opens_picker)
  if (s.kind === 'action' && t.kind === 'picker') {
    const entry = actions.catalog[s.id];
    if (!entry) return null;
    if (entry.opens_picker === t.id) return null;
    return {
      ...actions,
      catalog: { ...actions.catalog, [s.id]: { ...entry, opens_picker: t.id } },
    };
  }

  return null;
}

export function applyDisconnect(
  actions: ActionsFile,
  source: string,
  target: string,
): ActionsFile | null {
  const s = parseNodeId(source);
  const t = parseNodeId(target);
  if (!s || !t) return null;

  if ((s.kind === 'phase' && t.kind === 'action') || (s.kind === 'action' && t.kind === 'phase')) {
    const actionId = s.kind === 'action' ? s.id : t.id;
    const phaseId = s.kind === 'phase' ? s.id : t.id;
    const entry = actions.catalog[actionId];
    if (!entry) return null;
    const phases = (entry.phases ?? []).filter(p => p !== phaseId);
    return {
      ...actions,
      catalog: { ...actions.catalog, [actionId]: { ...entry, phases } },
    };
  }

  if (s.kind === 'action' && t.kind === 'school') {
    const entry = actions.catalog[s.id];
    if (!entry || entry.sets_school !== t.id) return null;
    const next = { ...entry };
    delete next.sets_school;
    return { ...actions, catalog: { ...actions.catalog, [s.id]: next } };
  }

  if (s.kind === 'action' && t.kind === 'picker') {
    const entry = actions.catalog[s.id];
    if (!entry || entry.opens_picker !== t.id) return null;
    const next = { ...entry };
    delete next.opens_picker;
    return { ...actions, catalog: { ...actions.catalog, [s.id]: next } };
  }

  return null;
}
