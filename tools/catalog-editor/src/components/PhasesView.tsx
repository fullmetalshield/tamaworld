import type { ActionsFile, ClubsFile } from '../types';
import { PHASES } from '../constants';

interface Props {
  actions: ActionsFile;
  clubs: ClubsFile;
}

// Phase-by-phase overview: which actions are gated to each phase, with the
// action's colour as a swatch and its meta-flags (sets_school, picker,
// requires_club, cooldown) summarised. Gives a bird's-eye view of how the
// "tree" branches across a pet's lifetime.
export function PhasesView({ actions, clubs }: Props) {
  return (
    <div className="phases-grid">
      {PHASES.map(phase => {
        const matched = Object.entries(actions.catalog).filter(([, e]) =>
          (e.phases ?? []).includes(phase.id)
        );
        return (
          <div key={phase.id} className="phase-card">
            <h3>{phase.label}</h3>
            <div className="meta">{phase.id} · {matched.length}개 행동</div>
            <div className="actions">
              {matched.length === 0 && <div className="meta">— 가능한 행동 없음 —</div>}
              {matched.map(([id, e]) => (
                <div key={id} className="pill" style={{ background: e.color ?? '#eee' }}>
                  <span>{e.label_key}</span>
                  <span className="id">
                    {e.sets_school && `→${e.sets_school}`}
                    {e.opens_picker && `[${e.opens_picker}]`}
                    {e.requires_club && '※클럽'}
                    {e.cooldown_minutes ? `·${e.cooldown_minutes}m쿨` : ''}
                  </span>
                </div>
              ))}
              {phase.id === 'young_adult' || phase.id === 'middle_aged' || phase.id === 'mature' ? (
                <div className="meta" style={{ marginTop: 6 }}>
                  · 동호회 가입 시 다음 활동들이 추가로 노출:
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4, marginTop: 4 }}>
                    {Object.entries(clubs.catalog).map(([cid, c]) => (
                      <span key={cid} className="pill" style={{ background: c.color, fontSize: 11 }}>{c.activity_label}</span>
                    ))}
                  </div>
                </div>
              ) : null}
            </div>
          </div>
        );
      })}
    </div>
  );
}
