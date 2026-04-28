import type {
  ActionsFile,
  ClubsFile,
  SchoolsFile,
  JobsFile,
  ValidationIssue,
} from './types';
import { PHASE_IDS, KNOWN_PICKERS } from './constants';

const HEX_RE = /^#([0-9a-f]{6}|[0-9a-f]{8})$/i;

export function validate(
  actions: ActionsFile | null,
  clubs: ClubsFile | null,
  schools: SchoolsFile | null,
  jobs: JobsFile | null,
): ValidationIssue[] {
  const issues: ValidationIssue[] = [];

  if (actions) {
    for (const [id, entry] of Object.entries(actions.catalog)) {
      for (const phase of entry.phases ?? []) {
        if (!PHASE_IDS.includes(phase)) {
          issues.push({
            catalog: 'actions', entryId: id, field: 'phases', level: 'error',
            message: `unknown phase id "${phase}"`,
          });
        }
      }
      if (entry.sets_school && schools && !schools.catalog[entry.sets_school]) {
        issues.push({
          catalog: 'actions', entryId: id, field: 'sets_school', level: 'error',
          message: `school "${entry.sets_school}" not found in schools.json`,
        });
      }
      if (entry.opens_picker && !KNOWN_PICKERS.includes(entry.opens_picker as 'club')) {
        issues.push({
          catalog: 'actions', entryId: id, field: 'opens_picker', level: 'error',
          message: `unknown picker target "${entry.opens_picker}"`,
        });
      }
      if (entry.color && !HEX_RE.test(entry.color)) {
        issues.push({
          catalog: 'actions', entryId: id, field: 'color', level: 'error',
          message: `invalid colour hex "${entry.color}"`,
        });
      }
      if (typeof entry.duration !== 'number' || entry.duration < 0) {
        issues.push({
          catalog: 'actions', entryId: id, field: 'duration', level: 'error',
          message: `duration must be a non-negative number`,
        });
      }
    }
  }

  if (clubs) {
    for (const [id, entry] of Object.entries(clubs.catalog)) {
      if (entry.color && !HEX_RE.test(entry.color)) {
        issues.push({
          catalog: 'clubs', entryId: id, field: 'color', level: 'error',
          message: `invalid colour hex "${entry.color}"`,
        });
      }
      if (!entry.label || !entry.activity_label || !entry.progress_label) {
        issues.push({
          catalog: 'clubs', entryId: id, level: 'warn',
          message: `missing label / activity_label / progress_label`,
        });
      }
    }
  }

  if (schools) {
    for (const [id, entry] of Object.entries(schools.catalog)) {
      if (typeof entry.cost_per_second !== 'number' || entry.cost_per_second < 0) {
        issues.push({
          catalog: 'schools', entryId: id, field: 'cost_per_second', level: 'error',
          message: `cost_per_second must be a non-negative number`,
        });
      }
    }
  }

  if (jobs) {
    if (jobs.starting_job && !jobs.catalog[jobs.starting_job]) {
      issues.push({
        catalog: 'jobs', entryId: jobs.starting_job, field: 'starting_job', level: 'error',
        message: `starting_job "${jobs.starting_job}" not in catalog`,
      });
    }
    for (const [id, entry] of Object.entries(jobs.catalog)) {
      if (typeof entry.income_per_second !== 'number' || entry.income_per_second < 0) {
        issues.push({
          catalog: 'jobs', entryId: id, field: 'income_per_second', level: 'error',
          message: `income_per_second must be a non-negative number`,
        });
      }
    }
  }

  return issues;
}
