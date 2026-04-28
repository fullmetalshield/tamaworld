import type { Node, Edge } from '@xyflow/react';
import type { ActionsFile, ClubsFile, SchoolsFile } from '../types';
import { PHASES, PHASE_IDS } from '../constants';

// Column x positions tuned so the four kinds of nodes don't overlap and
// edges read left-to-right (cause → effect).
const COL = {
  phase: 0,
  action: 360,
  picker: 760,
  ref: 1080,
};

export type GraphNodeKind = 'phase' | 'action' | 'school' | 'club' | 'picker';

export interface GraphNodeData extends Record<string, unknown> {
  kind: GraphNodeKind;
  entryId: string;
  label: string;
  color?: string;
}

// Encodes the relationship type into the edge id so we can parse it back
// during deletion: "<source-node-id>__<target-node-id>".
export function makeEdgeId(source: string, target: string): string {
  return `${source}__${target}`;
}

export function parseNodeId(nodeId: string): { kind: GraphNodeKind; id: string } | null {
  const idx = nodeId.indexOf(':');
  if (idx < 0) return null;
  return { kind: nodeId.slice(0, idx) as GraphNodeKind, id: nodeId.slice(idx + 1) };
}

export function buildGraph(
  actions: ActionsFile,
  clubs: ClubsFile,
  schools: SchoolsFile,
): { nodes: Node<GraphNodeData>[]; edges: Edge[] } {
  const nodes: Node<GraphNodeData>[] = [];
  const edges: Edge[] = [];

  const phaseY = (phaseIndex: number) => phaseIndex * 110;

  // Phase column ----------------------------------------------------------
  PHASES.forEach((p, i) => {
    nodes.push({
      id: `phase:${p.id}`,
      type: 'phase',
      position: { x: COL.phase, y: phaseY(i) },
      data: { kind: 'phase', entryId: p.id, label: p.label },
    });
  });

  // Actions ---------------------------------------------------------------
  // Stack actions vertically beside their *first* phase. Multiple actions
  // sharing a starting phase get stacked below each other (slot offset).
  const firstPhaseIdx = (entry: { phases?: string[] }) => {
    const ps = entry.phases ?? [];
    if (ps.length === 0) return PHASES.length;
    const idx = PHASE_IDS.indexOf(ps[0]);
    return idx < 0 ? PHASES.length : idx;
  };

  const sortedActions = Object.entries(actions.catalog).sort((a, b) => {
    const ai = firstPhaseIdx(a[1]);
    const bi = firstPhaseIdx(b[1]);
    if (ai !== bi) return ai - bi;
    return a[0].localeCompare(b[0]);
  });

  const phaseSlot = new Map<number, number>();
  for (const [aid, entry] of sortedActions) {
    const i = firstPhaseIdx(entry);
    const slot = phaseSlot.get(i) ?? 0;
    phaseSlot.set(i, slot + 1);
    nodes.push({
      id: `action:${aid}`,
      type: 'action',
      position: { x: COL.action, y: phaseY(i) + slot * 64 },
      data: { kind: 'action', entryId: aid, label: entry.label_key, color: entry.color },
    });
  }

  // Right-hand reference column: schools (top), clubs (below) -------------
  const schoolIds = Object.keys(schools.catalog);
  schoolIds.forEach((sid, i) => {
    const entry = schools.catalog[sid];
    nodes.push({
      id: `school:${sid}`,
      type: 'school',
      position: { x: COL.ref, y: i * 70 },
      data: { kind: 'school', entryId: sid, label: entry.label },
    });
  });

  const clubsStartY = schoolIds.length * 70 + 60;
  Object.entries(clubs.catalog).forEach(([cid, entry], i) => {
    nodes.push({
      id: `club:${cid}`,
      type: 'club',
      position: { x: COL.ref, y: clubsStartY + i * 60 },
      data: { kind: 'club', entryId: cid, label: entry.label, color: entry.color },
    });
  });

  // Single "club" picker node sits between actions and clubs.
  const pickerY = clubsStartY + (Object.keys(clubs.catalog).length * 60) / 2 - 30;
  nodes.push({
    id: 'picker:club',
    type: 'picker',
    position: { x: COL.picker, y: pickerY },
    data: { kind: 'picker', entryId: 'club', label: '동호회 선택' },
  });

  // Edges ----------------------------------------------------------------
  for (const [aid, entry] of sortedActions) {
    for (const phaseId of entry.phases ?? []) {
      edges.push({
        id: makeEdgeId(`phase:${phaseId}`, `action:${aid}`),
        source: `phase:${phaseId}`,
        target: `action:${aid}`,
        style: { stroke: '#d8c0c8' },
      });
    }
    if (entry.sets_school) {
      edges.push({
        id: makeEdgeId(`action:${aid}`, `school:${entry.sets_school}`),
        source: `action:${aid}`,
        target: `school:${entry.sets_school}`,
        style: { stroke: '#9bb87a' },
        label: 'sets_school',
        labelStyle: { fontSize: 10, fill: '#6c5d65' },
      });
    }
    if (entry.opens_picker) {
      edges.push({
        id: makeEdgeId(`action:${aid}`, `picker:${entry.opens_picker}`),
        source: `action:${aid}`,
        target: `picker:${entry.opens_picker}`,
        style: { stroke: '#a988d6' },
        label: 'opens_picker',
        labelStyle: { fontSize: 10, fill: '#6c5d65' },
      });
    }
  }

  // Picker → clubs are informational ("the picker offers all clubs"). The
  // animated, dashed style + non-deletable flag signals these edges aren't
  // editable from the canvas.
  for (const cid of Object.keys(clubs.catalog)) {
    edges.push({
      id: makeEdgeId('picker:club', `club:${cid}`),
      source: 'picker:club',
      target: `club:${cid}`,
      animated: true,
      style: { stroke: '#cdb6e8', strokeDasharray: '4 4' },
      deletable: false,
    });
  }

  return { nodes, edges };
}
