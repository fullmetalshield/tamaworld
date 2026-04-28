import { useCallback, useEffect, useMemo } from 'react';
import {
  ReactFlow, Background, Controls, MiniMap,
  useNodesState, useEdgesState, addEdge,
  type Connection, type Edge,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';
import type { ActionsFile, ClubsFile, SchoolsFile } from '../types';
import { buildGraph, parseNodeId, makeEdgeId } from '../lib/buildGraph';
import { applyConnect, applyDisconnect } from '../lib/applyConnection';
import { nodeTypes } from './TreeNodes';

interface Props {
  actions: ActionsFile;
  clubs: ClubsFile;
  schools: SchoolsFile;
  onActionsChange: (next: ActionsFile) => void;
  onSelectAction: (id: string) => void;
}

export function TreeView({ actions, clubs, schools, onActionsChange, onSelectAction }: Props) {
  // Recompute the graph whenever any of the three catalogs change.
  const graph = useMemo(
    () => buildGraph(actions, clubs, schools),
    [actions, clubs, schools],
  );
  const [nodes, setNodes, onNodesChange] = useNodesState(graph.nodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(graph.edges);

  useEffect(() => {
    setNodes(graph.nodes);
    setEdges(graph.edges);
  }, [graph, setNodes, setEdges]);

  const onConnect = useCallback((conn: Connection) => {
    if (!conn.source || !conn.target) return;
    const next = applyConnect(actions, conn.source, conn.target);
    if (next) {
      onActionsChange(next);
      // Optimistically add edge so it appears immediately; the next graph
      // rebuild from props will replace it with the canonical one.
      const id = makeEdgeId(conn.source, conn.target);
      setEdges(eds => addEdge({ ...conn, id }, eds));
    }
  }, [actions, onActionsChange, setEdges]);

  const onEdgesDelete = useCallback((toDelete: Edge[]) => {
    let next = actions;
    for (const e of toDelete) {
      if (!e.source || !e.target) continue;
      // Picker → Club edges are intentionally non-editable.
      const t = parseNodeId(e.target);
      if (t?.kind === 'club') continue;
      const updated = applyDisconnect(next, e.source, e.target);
      if (updated) next = updated;
    }
    if (next !== actions) onActionsChange(next);
  }, [actions, onActionsChange]);

  return (
    <div style={{ width: '100%', height: '100%' }}>
      <ReactFlow
        nodes={nodes}
        edges={edges}
        nodeTypes={nodeTypes}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onConnect={onConnect}
        onEdgesDelete={onEdgesDelete}
        onNodeClick={(_, node) => {
          const parsed = parseNodeId(node.id);
          if (parsed?.kind === 'action') onSelectAction(parsed.id);
        }}
        fitView
        fitViewOptions={{ padding: 0.15 }}
        minZoom={0.3}
        maxZoom={1.5}
        defaultEdgeOptions={{ deletable: true }}
        proOptions={{ hideAttribution: true }}
      >
        <Background gap={20} color="#eee" />
        <Controls position="bottom-right" />
        <MiniMap pannable zoomable position="bottom-left" nodeStrokeWidth={2} />
      </ReactFlow>
    </div>
  );
}
