import type {
  ActionEntry, ClubEntry, SchoolEntry, JobEntry, CatalogName,
} from '../types';
import { PHASES, STAT_KEYS, STAT_LABELS, KNOWN_PICKERS } from '../constants';

type EntryShape = ActionEntry | ClubEntry | SchoolEntry | JobEntry;

interface Props {
  catalog: CatalogName;
  entryId: string;
  entry: EntryShape;
  schoolIds: string[];
  onChange: (next: EntryShape) => void;
}

export function Inspector({ catalog, entryId, entry, schoolIds, onChange }: Props) {
  return (
    <div className="inspector">
      <h2><span style={{ fontFamily: 'monospace' }}>{entryId}</span></h2>
      {catalog === 'actions' && (
        <ActionFields entry={entry as ActionEntry} schoolIds={schoolIds} onChange={onChange as (n: ActionEntry) => void} />
      )}
      {catalog === 'clubs' && (
        <ClubFields entry={entry as ClubEntry} onChange={onChange as (n: ClubEntry) => void} />
      )}
      {catalog === 'schools' && (
        <SchoolFields entry={entry as SchoolEntry} onChange={onChange as (n: SchoolEntry) => void} />
      )}
      {catalog === 'jobs' && (
        <JobFields entry={entry as JobEntry} onChange={onChange as (n: JobEntry) => void} />
      )}
    </div>
  );
}

function TextField({ label, value, onChange, placeholder }: { label: string; value: string; onChange: (v: string) => void; placeholder?: string }) {
  return (
    <div className="field">
      <label>{label}</label>
      <input type="text" value={value} placeholder={placeholder} onChange={e => onChange(e.target.value)} />
    </div>
  );
}

function NumberField({ label, value, onChange, min }: { label: string; value: number; onChange: (v: number) => void; min?: number }) {
  return (
    <div className="field">
      <label>{label}</label>
      <input
        type="number"
        value={Number.isFinite(value) ? value : 0}
        min={min}
        onChange={e => onChange(Number(e.target.value))}
      />
    </div>
  );
}

function ColorField({ label, value, onChange }: { label: string; value: string; onChange: (v: string) => void }) {
  return (
    <div className="field">
      <label>{label}</label>
      <div className="row-color">
        <input
          type="color"
          value={normalizeHexForPicker(value)}
          onChange={e => onChange(e.target.value.toUpperCase())}
        />
        <input type="text" value={value ?? ''} onChange={e => onChange(e.target.value)} placeholder="#RRGGBB" />
      </div>
    </div>
  );
}

function normalizeHexForPicker(v: string): string {
  if (typeof v !== 'string') return '#FFFFFF';
  const m = v.match(/^#([0-9a-f]{6})/i);
  return m ? `#${m[1]}` : '#FFFFFF';
}

function PhaseChips({ value, onChange }: { value: string[]; onChange: (v: string[]) => void }) {
  const set = new Set(value ?? []);
  function toggle(id: string) {
    const next = new Set(set);
    if (next.has(id)) next.delete(id); else next.add(id);
    onChange(PHASES.filter(p => next.has(p.id)).map(p => p.id));
  }
  return (
    <div className="field">
      <label>phases</label>
      <div className="phase-chips">
        {PHASES.map(p => (
          <button
            key={p.id}
            type="button"
            className={set.has(p.id) ? 'on' : ''}
            onClick={() => toggle(p.id)}
            title={p.id}
          >{p.label}</button>
        ))}
      </div>
    </div>
  );
}

function ActionFields({ entry, schoolIds, onChange }: { entry: ActionEntry; schoolIds: string[]; onChange: (n: ActionEntry) => void }) {
  const set = (patch: Partial<ActionEntry>) => onChange({ ...entry, ...patch });
  return (
    <>
      <TextField label="label_key" value={entry.label_key} onChange={v => set({ label_key: v })} />
      <TextField label="progress_label_key" value={entry.progress_label_key ?? ''} onChange={v => set({ progress_label_key: v })} />
      <NumberField label="duration (game-min)" value={entry.duration} onChange={v => set({ duration: v })} min={0} />
      <NumberField label="money_reward" value={entry.money_reward} onChange={v => set({ money_reward: v })} />
      <ColorField label="color" value={entry.color} onChange={v => set({ color: v })} />
      <PhaseChips value={entry.phases ?? []} onChange={v => set({ phases: v })} />

      <div className="field-section">effects (스탯 변화)</div>
      {STAT_KEYS.map(k => (
        <NumberField
          key={k}
          label={`${STAT_LABELS[k]} (${k})`}
          value={entry.effects?.[k] ?? 0}
          onChange={v => {
            const next = { ...(entry.effects ?? {}) };
            if (v === 0) delete next[k]; else next[k] = v;
            set({ effects: next });
          }}
        />
      ))}

      <div className="field-section">advanced</div>
      <div className="field">
        <label>sets_school</label>
        <select value={entry.sets_school ?? ''} onChange={e => set({ sets_school: e.target.value || undefined })}>
          <option value="">— (none) —</option>
          {schoolIds.map(id => <option key={id} value={id}>{id}</option>)}
        </select>
      </div>
      <div className="field">
        <label>opens_picker</label>
        <select value={entry.opens_picker ?? ''} onChange={e => set({ opens_picker: e.target.value || undefined })}>
          <option value="">— (none) —</option>
          {KNOWN_PICKERS.map(p => <option key={p} value={p}>{p}</option>)}
        </select>
      </div>
      <div className="field">
        <label>requires_club</label>
        <input type="checkbox" checked={!!entry.requires_club} onChange={e => set({ requires_club: e.target.checked || undefined })} />
      </div>
      <NumberField label="cooldown_minutes" value={entry.cooldown_minutes ?? 0} onChange={v => set({ cooldown_minutes: v || undefined })} min={0} />
    </>
  );
}

function ClubFields({ entry, onChange }: { entry: ClubEntry; onChange: (n: ClubEntry) => void }) {
  const set = (patch: Partial<ClubEntry>) => onChange({ ...entry, ...patch });
  return (
    <>
      <TextField label="label" value={entry.label} onChange={v => set({ label: v })} />
      <TextField label="activity_label" value={entry.activity_label} onChange={v => set({ activity_label: v })} placeholder="예: 독서하기" />
      <TextField label="progress_label" value={entry.progress_label} onChange={v => set({ progress_label: v })} placeholder="예: 독서 중" />
      <ColorField label="color" value={entry.color} onChange={v => set({ color: v })} />
    </>
  );
}

function SchoolFields({ entry, onChange }: { entry: SchoolEntry; onChange: (n: SchoolEntry) => void }) {
  const set = (patch: Partial<SchoolEntry>) => onChange({ ...entry, ...patch });
  return (
    <>
      <TextField label="label" value={entry.label} onChange={v => set({ label: v })} />
      <NumberField label="cost_per_second" value={entry.cost_per_second} onChange={v => set({ cost_per_second: v })} min={0} />
    </>
  );
}

function JobFields({ entry, onChange }: { entry: JobEntry; onChange: (n: JobEntry) => void }) {
  const set = (patch: Partial<JobEntry>) => onChange({ ...entry, ...patch });
  return (
    <>
      <TextField label="label" value={entry.label} onChange={v => set({ label: v })} />
      <TextField label="category" value={entry.category} onChange={v => set({ category: v })} />
      <NumberField label="income_per_second" value={entry.income_per_second} onChange={v => set({ income_per_second: v })} />
    </>
  );
}
