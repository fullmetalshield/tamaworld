import { Handle, Position, type NodeProps } from '@xyflow/react';
import type { GraphNodeData } from '../lib/buildGraph';

// Compact custom node components rendered by React Flow. Each kind has a
// distinct visual + handle setup so connections are intuitive: phases on
// the left flow rightward into actions, which flow into schools/pickers,
// which flow into clubs.

const COMMON: React.CSSProperties = {
  borderRadius: 10,
  padding: '8px 12px',
  fontSize: 13,
  fontFamily: 'inherit',
  minWidth: 140,
  textAlign: 'center',
  border: '1px solid var(--border)',
  background: 'var(--panel)',
  boxShadow: '0 1px 2px rgba(0,0,0,0.04)',
};

const HANDLE_STYLE: React.CSSProperties = {
  width: 8,
  height: 8,
  background: '#d39ba6',
  border: '1px solid white',
};

export function PhaseNode({ data, selected }: NodeProps) {
  const d = data as GraphNodeData;
  return (
    <div style={{ ...COMMON, background: '#fbe4e9', borderColor: selected ? 'var(--accent)' : '#e7c4cc' }}>
      <div style={{ fontWeight: 600 }}>{d.label}</div>
      <div style={{ fontSize: 10, color: 'var(--ink-soft)', fontFamily: 'monospace' }}>{d.entryId}</div>
      <Handle id="src" type="source" position={Position.Right} style={HANDLE_STYLE} />
    </div>
  );
}

export function ActionNode({ data, selected }: NodeProps) {
  const d = data as GraphNodeData;
  const bg = d.color ?? '#eaeaea';
  return (
    <div style={{ ...COMMON, background: bg, borderColor: selected ? 'var(--accent)' : '#00000020' }}>
      <Handle id="tgt" type="target" position={Position.Left} style={HANDLE_STYLE} />
      <div style={{ fontWeight: 600 }}>{d.label}</div>
      <div style={{ fontSize: 10, color: '#00000080', fontFamily: 'monospace' }}>{d.entryId}</div>
      <Handle id="src" type="source" position={Position.Right} style={HANDLE_STYLE} />
    </div>
  );
}

export function SchoolNode({ data, selected }: NodeProps) {
  const d = data as GraphNodeData;
  return (
    <div style={{ ...COMMON, background: '#e6f1d8', borderColor: selected ? 'var(--accent)' : '#bdd49a' }}>
      <Handle id="tgt" type="target" position={Position.Left} style={HANDLE_STYLE} />
      <div style={{ fontWeight: 600 }}>🏫 {d.label}</div>
      <div style={{ fontSize: 10, color: 'var(--ink-soft)', fontFamily: 'monospace' }}>{d.entryId}</div>
    </div>
  );
}

export function ClubNode({ data, selected }: NodeProps) {
  const d = data as GraphNodeData;
  const bg = d.color ?? '#eaeaea';
  return (
    <div style={{ ...COMMON, background: bg, borderColor: selected ? 'var(--accent)' : '#00000020' }}>
      <Handle id="tgt" type="target" position={Position.Left} style={HANDLE_STYLE} />
      <div style={{ fontWeight: 600 }}>{d.label}</div>
      <div style={{ fontSize: 10, color: '#00000080', fontFamily: 'monospace' }}>{d.entryId}</div>
    </div>
  );
}

export function PickerNode({ data, selected }: NodeProps) {
  const d = data as GraphNodeData;
  return (
    <div style={{
      ...COMMON, background: '#f1e6fa', borderColor: selected ? 'var(--accent)' : '#cdb6e8',
      borderStyle: 'dashed', minWidth: 120,
    }}>
      <Handle id="tgt" type="target" position={Position.Left} style={HANDLE_STYLE} />
      <div style={{ fontWeight: 600 }}>▷ {d.label}</div>
      <div style={{ fontSize: 10, color: 'var(--ink-soft)', fontFamily: 'monospace' }}>picker:{d.entryId}</div>
      <Handle id="src" type="source" position={Position.Right} style={HANDLE_STYLE} />
    </div>
  );
}

export const nodeTypes = {
  phase: PhaseNode,
  action: ActionNode,
  school: SchoolNode,
  club: ClubNode,
  picker: PickerNode,
};
