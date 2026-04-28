// JSON shapes mirror data/*.json. Anything optional in the editor must
// also be optional here so we can render half-filled entries during edit.

export type HexColor = string; // e.g. "#FFC7D6"

export type StatKey = 'strength' | 'intelligence' | 'charisma' | 'stamina' | 'agility' | 'luck';

export interface ActionEntry {
  label_key: string;
  progress_label_key?: string;
  duration: number;
  effects: Partial<Record<StatKey, number>>;
  money_reward: number;
  color: HexColor;
  phases: string[];
  sets_school?: string;
  opens_picker?: string;
  requires_club?: boolean;
  cooldown_minutes?: number;
}

export interface ClubEntry {
  label: string;
  activity_label: string;
  progress_label: string;
  color: HexColor;
}

export interface SchoolEntry {
  label: string;
  cost_per_second: number;
}

export interface JobEntry {
  label: string;
  category: string;
  income_per_second: number;
}

export interface ActionsFile {
  catalog: Record<string, ActionEntry>;
}

export interface ClubsFile {
  catalog: Record<string, ClubEntry>;
  npc_names: string[];
}

export interface SchoolsFile {
  catalog: Record<string, SchoolEntry>;
}

export interface JobsFile {
  starting_job: string;
  catalog: Record<string, JobEntry>;
}

export type CatalogName = 'actions' | 'clubs' | 'schools' | 'jobs';

export interface ValidationIssue {
  catalog: CatalogName;
  entryId: string;
  field?: string;
  level: 'error' | 'warn';
  message: string;
}
