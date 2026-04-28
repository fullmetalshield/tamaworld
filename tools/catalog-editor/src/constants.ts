// Mirror of scripts/Stats.gd PHASES (id + label only). Keep in sync by hand
// — phases are a small, stable enum and changes happen rarely.
export const PHASES: { id: string; label: string }[] = [
  { id: 'egg',          label: '알' },
  { id: 'newborn',      label: '신생아기' },
  { id: 'infant',       label: '영아기' },
  { id: 'toddler',      label: '유아기' },
  { id: 'child',        label: '아동기' },
  { id: 'teen',         label: '청소년기' },
  { id: 'young_adult',  label: '청년기' },
  { id: 'middle_aged',  label: '중년기' },
  { id: 'mature',       label: '장년기' },
  { id: 'elder',        label: '노년기' },
];

export const PHASE_IDS = PHASES.map(p => p.id);

export const STAT_KEYS = [
  'strength',
  'intelligence',
  'charisma',
  'stamina',
  'agility',
  'luck',
] as const;

export const STAT_LABELS: Record<string, string> = {
  strength: '근력',
  intelligence: '지능',
  charisma: '매력',
  stamina: '체력',
  agility: '민첩',
  luck: '운',
};

export const KNOWN_PICKERS = ['club'] as const;
