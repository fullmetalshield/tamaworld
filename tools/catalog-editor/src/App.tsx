import { useEffect, useMemo, useState } from 'react';
import type {
  ActionsFile, ClubsFile, SchoolsFile, JobsFile,
  CatalogName, ActionEntry, ClubEntry, SchoolEntry, JobEntry,
  ValidationIssue,
} from './types';
import { loadCatalog, saveCatalog } from './api';
import { validate } from './validation';
import { Inspector } from './components/Inspector';
import { PhasesView } from './components/PhasesView';

type TabName = CatalogName | 'phases';

const TABS: { id: TabName; label: string }[] = [
  { id: 'actions', label: '행동' },
  { id: 'clubs',   label: '동호회' },
  { id: 'schools', label: '학교' },
  { id: 'jobs',    label: '직업' },
  { id: 'phases',  label: '단계 미리보기' },
];

const DEFAULT_ENTRIES: Record<CatalogName, () => any> = {
  actions: (): ActionEntry => ({
    label_key: 'ACTION_NEW',
    progress_label_key: 'ACTION_NEW_PROGRESS',
    duration: 60,
    effects: {},
    money_reward: 0,
    color: '#EAEAEA',
    phases: [],
  }),
  clubs: (): ClubEntry => ({
    label: '새 동호회', activity_label: '활동하기', progress_label: '활동 중', color: '#EAEAEA',
  }),
  schools: (): SchoolEntry => ({ label: '새 학교', cost_per_second: 0 }),
  jobs:    (): JobEntry    => ({ label: '새 직업', category: 'office', income_per_second: 1 }),
};

export default function App() {
  const [tab, setTab] = useState<TabName>('actions');
  const [actions, setActions] = useState<ActionsFile | null>(null);
  const [clubs, setClubs]     = useState<ClubsFile   | null>(null);
  const [schools, setSchools] = useState<SchoolsFile | null>(null);
  const [jobs, setJobs]       = useState<JobsFile    | null>(null);
  const [dirty, setDirty]     = useState<Set<CatalogName>>(new Set());
  const [selected, setSelected] = useState<Record<CatalogName, string | null>>({
    actions: null, clubs: null, schools: null, jobs: null,
  });
  const [newId, setNewId] = useState('');
  const [status, setStatus] = useState('');

  useEffect(() => {
    Promise.all([
      loadCatalog<ActionsFile>('actions'),
      loadCatalog<ClubsFile>('clubs'),
      loadCatalog<SchoolsFile>('schools'),
      loadCatalog<JobsFile>('jobs'),
    ]).then(([a, c, s, j]) => {
      setActions(a); setClubs(c); setSchools(s); setJobs(j);
      setStatus('로드 완료');
    }).catch(err => setStatus(`로드 실패: ${err.message}`));
  }, []);

  const issues: ValidationIssue[] = useMemo(
    () => validate(actions, clubs, schools, jobs),
    [actions, clubs, schools, jobs],
  );

  function markDirty(name: CatalogName) {
    setDirty(prev => new Set(prev).add(name));
  }

  async function saveAll() {
    setStatus('저장 중...');
    try {
      const tasks: Promise<void>[] = [];
      if (dirty.has('actions') && actions) tasks.push(saveCatalog('actions', actions));
      if (dirty.has('clubs')   && clubs)   tasks.push(saveCatalog('clubs',   clubs));
      if (dirty.has('schools') && schools) tasks.push(saveCatalog('schools', schools));
      if (dirty.has('jobs')    && jobs)    tasks.push(saveCatalog('jobs',    jobs));
      await Promise.all(tasks);
      setDirty(new Set());
      setStatus(`저장 완료 (${new Date().toLocaleTimeString()})`);
    } catch (err: any) {
      setStatus(`저장 실패: ${err.message}`);
    }
  }

  function getFile(name: CatalogName): { catalog: Record<string, any> } | null {
    switch (name) {
      case 'actions': return actions;
      case 'clubs':   return clubs;
      case 'schools': return schools;
      case 'jobs':    return jobs;
    }
  }

  function setEntry(name: CatalogName, id: string, entry: any) {
    if (name === 'actions' && actions) {
      setActions({ ...actions, catalog: { ...actions.catalog, [id]: entry } });
    } else if (name === 'clubs' && clubs) {
      setClubs({ ...clubs, catalog: { ...clubs.catalog, [id]: entry } });
    } else if (name === 'schools' && schools) {
      setSchools({ ...schools, catalog: { ...schools.catalog, [id]: entry } });
    } else if (name === 'jobs' && jobs) {
      setJobs({ ...jobs, catalog: { ...jobs.catalog, [id]: entry } });
    }
    markDirty(name);
  }

  function addEntry(name: CatalogName) {
    const id = newId.trim();
    if (!id) return;
    const file = getFile(name);
    if (!file) return;
    if (file.catalog[id]) {
      setStatus(`이미 존재: ${id}`);
      return;
    }
    setEntry(name, id, DEFAULT_ENTRIES[name]());
    setSelected(prev => ({ ...prev, [name]: id }));
    setNewId('');
  }

  function removeEntry(name: CatalogName, id: string) {
    if (!confirm(`정말 "${id}"를 삭제할까요?`)) return;
    const file = getFile(name);
    if (!file) return;
    const next = { ...file.catalog };
    delete next[id];
    if (name === 'actions' && actions) setActions({ ...actions, catalog: next });
    else if (name === 'clubs' && clubs) setClubs({ ...clubs, catalog: next });
    else if (name === 'schools' && schools) setSchools({ ...schools, catalog: next });
    else if (name === 'jobs' && jobs) setJobs({ ...jobs, catalog: next });
    setSelected(prev => ({ ...prev, [name]: null }));
    markDirty(name);
  }

  const ready = actions && clubs && schools && jobs;

  return (
    <div className="app">
      <div className="toolbar">
        <h1>TamaWorld Catalog Editor</h1>
        <div className="tabs">
          {TABS.map(t => (
            <button
              key={t.id}
              className={`tab ${tab === t.id ? 'active' : ''}`}
              onClick={() => setTab(t.id)}
            >{t.label}</button>
          ))}
        </div>
        <div className="spacer" />
        <span className="status">{status}{dirty.size > 0 ? ` · 변경됨 (${[...dirty].join(', ')})` : ''}</span>
        <button
          className="action primary"
          disabled={dirty.size === 0}
          onClick={saveAll}
        >저장</button>
      </div>

      <div className={`validation-bar ${issues.length === 0 ? 'empty' : ''}`}>
        {issues.length === 0 ? (
          <span>검증 통과 — 문제 없음</span>
        ) : (
          issues.slice(0, 5).map((iss, i) => (
            <span key={i} className={`issue ${iss.level}`}>
              [{iss.catalog}/{iss.entryId}{iss.field ? `.${iss.field}` : ''}] {iss.message}
            </span>
          ))
        )}
        {issues.length > 5 && <span>· 외 {issues.length - 5}건</span>}
      </div>

      {!ready && <div className="empty-pane">불러오는 중...</div>}

      {ready && tab === 'phases' && actions && clubs && (
        <PhasesView actions={actions} clubs={clubs} />
      )}

      {ready && tab !== 'phases' && (
        <CatalogPanel
          name={tab}
          file={getFile(tab)!}
          schoolIds={Object.keys(schools!.catalog)}
          selectedId={selected[tab]}
          onSelect={id => setSelected(prev => ({ ...prev, [tab]: id }))}
          onChangeEntry={(id, entry) => setEntry(tab, id, entry)}
          onAdd={() => addEntry(tab)}
          onRemove={id => removeEntry(tab, id)}
          newId={newId}
          setNewId={setNewId}
        />
      )}
    </div>
  );
}

interface PanelProps {
  name: CatalogName;
  file: { catalog: Record<string, any> };
  schoolIds: string[];
  selectedId: string | null;
  onSelect: (id: string) => void;
  onChangeEntry: (id: string, entry: any) => void;
  onAdd: () => void;
  onRemove: (id: string) => void;
  newId: string;
  setNewId: (v: string) => void;
}

function CatalogPanel({ name, file, schoolIds, selectedId, onSelect, onChangeEntry, onAdd, onRemove, newId, setNewId }: PanelProps) {
  const ids = Object.keys(file.catalog);
  const selected = selectedId ? file.catalog[selectedId] : null;
  return (
    <div className="main">
      <div style={{ display: 'flex', flexDirection: 'column', borderRight: '1px solid var(--border)' }}>
        <div className="list-panel" style={{ flex: 1 }}>
          {ids.map(id => {
            const entry = file.catalog[id];
            const swatch = (entry && typeof entry.color === 'string') ? entry.color : '#dddddd';
            const label = entry?.label ?? entry?.label_key ?? id;
            return (
              <div
                key={id}
                className={`list-item ${selectedId === id ? 'active' : ''}`}
                onClick={() => onSelect(id)}
              >
                <span className="swatch" style={{ background: swatch }} />
                <span className="label">{label}</span>
                <span className="id">{id}</span>
              </div>
            );
          })}
        </div>
        <div className="list-actions">
          <input
            value={newId}
            onChange={e => setNewId(e.target.value)}
            placeholder="새 id (영문)"
            onKeyDown={e => { if (e.key === 'Enter') onAdd(); }}
          />
          <button onClick={onAdd}>추가</button>
        </div>
      </div>
      {selected ? (
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          <Inspector
            catalog={name}
            entryId={selectedId!}
            entry={selected}
            schoolIds={schoolIds}
            onChange={next => onChangeEntry(selectedId!, next)}
          />
          <div style={{ padding: '8px 24px', borderTop: '1px solid var(--border)' }}>
            <button onClick={() => onRemove(selectedId!)} style={{
              padding: '6px 14px', borderRadius: 8, border: '1px solid var(--border)',
              background: 'white', color: 'var(--error)', cursor: 'pointer',
            }}>이 항목 삭제</button>
          </div>
        </div>
      ) : (
        <div className="empty-pane">왼쪽에서 항목을 선택하세요</div>
      )}
    </div>
  );
}
