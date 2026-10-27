#!/usr/bin/env node
'use strict';
/*
 * redmine.js — single-file Redmine CLI (no dependencies; Node 18+ for global fetch).
 *
 * Built for the susanoo Redmine instance, with this project's conventions baked in.
 * Safe to share: the API key is read from the environment, never hardcoded.
 *
 *   export REDMINE_API_KEY=xxxx-your-key-xxxx        # required
 *   export REDMINE_URL=https://redmine.susanoo.pl    # optional (default)
 *
 * State (for `inbox`) is stored REMOTELY in a dedicated Redmine issue in the Dev project,
 * so it is shared across machines/sessions without any local file. Override with:
 *   export REDMINE_STATE_PROJECT=ai-coders           # project for the state issue (default: your type memory)
 *   export REDMINE_STATE_SUBJECT="..."               # marker subject of the state issue
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const BASE = (process.env.REDMINE_URL || 'https://redmine.susanoo.pl').replace(/\/+$/, '');
const KEY = process.env.REDMINE_API_KEY;
// A stable, per-session id. In the COI sandbox os.hostname() is the unique container name, stable
// across CLI invocations within one session and distinct across parallel sessions. Override with
// REDMINE_SESSION. Used for cooperative work-claiming (claim/release/wip tags) between parallel
// containers of the SAME agent. NOT used for inbox state any more (see STATE_SUBJECT below) —
// containers are ephemeral, so a per-session inbox cursor reset every session and silently
// swallowed pre-existing comments (the "inbox-baseline trap", ais#45914).
const SESSION = String(process.env.REDMINE_SESSION || os.hostname() || 'default').replace(/\s+/g, '-');

// --- Conventions for this instance (names are convenience; numeric ids always work) ---
const PROJECTS = {
  dev: 82, development: 82, bugs: 88, coi: 90, karafka: 73,
  other: 86, ruby: 84, shoryuken: 85, social: 87,
  apartament: 55,
  // commons = ais (92). Type memory lives in the plural 'ai-<role>s' projects, shared by all slots.
  ai: 92, ais: 92, commons: 92,
  ai_pms: 91, ai_pm: 91, agentic_memory: 91, memory: 91,   // AI PMs (91)
};

// --- Which agent am I? login = ai-<role>-<slot>, self-discovered at boot (see [[ais:Bootstrap]]). ---
const AGENT = String(process.env.REDMINE_AGENT || '').trim();
const ROLE = (AGENT.match(/^ai-([a-z]+)-\d+$/) || [])[1] || '';   // coder | pm | writer | ...
// A type's memory is the plural 'ai-<role>s' project, shared by every slot of the type. Prefer the
// value bootstrap exports; else derive it from the role. Identifiers work anywhere a numeric id does.
// English plural: roles ending in ch/sh/s/x/z take -es (coach -> coaches), else -s.
const pluralRole = (r) => (/(?:ch|sh|s|x|z)$/.test(r) ? r + 'es' : r + 's');
const MEMORY_PROJECT = String(process.env.REDMINE_MEMORY_PROJECT || (ROLE ? `ai-${pluralRole(ROLE)}` : '')).trim();
// login / role / "maciej" -> Redmine user id, for --assign convenience (see [[ais:Agents]]).
// Slots are distinct users; a bare role aliases to that role's slot 1.
const USERS = {
  maciej: 1,
  'ai-pm-1': 252, 'ai-writer-1': 254, 'ai-researcher-1': 255, 'ai-coder-1': 256,
  'ai-coder-2': 263, 'ai-coder-3': 264, 'ai-coder-4': 265, 'ai-coder-5': 266,
  'ai-curator-1': 268, 'ai-butler-1': 270,
  'ai-pm': 252, 'ai-writer': 254, 'ai-researcher': 255, 'ai-coder': 256,
  'ai-curator': 268, 'ai-butler': 270,
};
// Type GROUPS (plural). NEW / "up-for-grabs" work is assigned to the group -> the first free slot
// claims it by re-assigning to itself. Active work handed back goes to a specific slot, not the group.
const GROUPS = {
  'ai-pms': 260, 'ai-coders': 258, 'ai-researchers': 259, 'ai-writers': 261,
  'ai-coaches': 262, 'ai-curators': 267, 'ai-butlers': 269,
};
const TRACKERS = {
  blad: 1, 'błąd': 1, bug: 1, zadanie: 2, task: 2, wsparcie: 3, support: 3,
  koncepcja: 5, concept: 5, artykuly: 6, article: 6, usprawnienie: 7, enhancement: 7,
  aktualizacja: 9, biografia: 10, korekta: 11, backlog: 12, research: 13,
  awaria: 14, zadanie_cykliczne: 15, recurring_task: 15, zakupy: 16,
  inspiracje: 17, inspiration: 17, reklamacja: 18, complaint: 18, autonomous: 19,
};
const STATUSES = { // 3/5/6 are "closed"; 1/2/4/7 are "open"
  nowy: 1, new: 1, w_toku: 2, in_progress: 2, rozwiazany: 3, resolved: 3,
  odpowiedz: 4, 'odpowiedź': 4, answer: 4, reply: 4,
  zamkniety: 5, 'zamknięty': 5, closed: 5, odrzucony: 6, rejected: 6,
  sprawdzony: 7, verified: 7, reviewed: 7, approved: 7,
};
const PRIORITIES = {
  niski: 3, low: 3, normalny: 4, normal: 4, wysoki: 5, high: 5,
  pilny: 6, urgent: 6, natychmiastowy: 7, immediate: 7,
};

// --- remote state config ---
const STATE_PROJECT = process.env.REDMINE_STATE_PROJECT || MEMORY_PROJECT || 'ais';
// Per-AGENT (not per-session/container) subject => the inbox cursor survives across a slot's
// ephemeral containers, so a fresh session correctly reports only what's new since the slot last
// checked, instead of re-baselining and swallowing everything (ais#45914). Two containers of the
// SAME slot running concurrently share one cursor -- harmless (same user), and slots are the
// concurrency unit anyway. Falls back to SESSION when AGENT isn't set (e.g. no bootstrap identity).
const STATE_SUBJECT_PREFIX = '[redmine.js] inbox state';
const STATE_SUBJECT = process.env.REDMINE_STATE_SUBJECT || `${STATE_SUBJECT_PREFIX} · ${AGENT || SESSION}`;
const STATE_BEGIN = '<<<REDMINE-JS-STATE';
const STATE_END = 'REDMINE-JS-STATE>>>';

function die(msg) { console.error('error: ' + msg); process.exit(1); }
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// Exponential backoff for transient failures: 250ms, 500ms, 1s, ... capped at 8s.
function backoff(attempt) { return Math.min(8000, 250 * 2 ** (attempt - 1)); }
function resolve(map, v, kind) {
  if (v == null) return null;
  if (/^\d+$/.test(String(v))) return Number(v);
  const k = String(v).toLowerCase().replace(/[\s-]/g, '_');
  if (map[k] != null) return map[k];
  die(`unknown ${kind}: "${v}" (known: ${[...new Set(Object.keys(map))].join(', ')})`);
}

// Transient failures worth retrying (rate-limit + gateway/unavailable); never retry 4xx validation.
const RETRY_STATUS = new Set([429, 502, 503, 504]);
const MAX_TRIES = 4; // 1 attempt + up to 3 retries
async function api(method, p, body) {
  if (!KEY) die('REDMINE_API_KEY is not set');
  if (typeof fetch === 'undefined') die('global fetch missing — needs Node 18+');
  if (process.env.REDMINE_DEBUG) process.stderr.write(`[redmine] ${method} ${p}\n`);
  let lastErr = null;
  for (let attempt = 1; attempt <= MAX_TRIES; attempt++) {
    let res;
    try {
      res = await fetch(BASE + p, {
        method,
        headers: { 'X-Redmine-API-Key': KEY, 'Content-Type': 'application/json' },
        body: body ? JSON.stringify(body) : undefined,
      });
    } catch (e) { // network error (DNS/reset/timeout) — transient, retry
      lastErr = e;
      if (attempt < MAX_TRIES) { await sleep(backoff(attempt)); continue; }
      return die(`network error on ${method} ${p} after ${MAX_TRIES} tries — ${(e && e.message) || e}`);
    }
    if (RETRY_STATUS.has(res.status) && attempt < MAX_TRIES) { // transient server/rate-limit — retry
      const ra = Number(res.headers.get('retry-after'));
      await sleep(Number.isFinite(ra) && ra > 0 ? ra * 1000 : backoff(attempt));
      continue;
    }
    const text = await res.text();
    let json = null;
    if (text) { try { json = JSON.parse(text); } catch (_) {} }
    if (res.status >= 400) { // 4xx (and exhausted 5xx) — hard error, no more retries
      const detail = json && json.errors ? json.errors.join('; ') : (text || '').slice(0, 300);
      return die(`HTTP ${res.status} on ${method} ${p} — ${detail}`);
    }
    return { status: res.status, json, text };
  }
  return die(`request failed on ${method} ${p} — ${(lastErr && lastErr.message) || 'exhausted retries'}`);
}

async function paginate(pathBase) {
  const sep = pathBase.includes('?') ? '&' : '?';
  const out = [];
  let offset = 0;
  for (;;) {
    const { json } = await api('GET', `${pathBase}${sep}limit=100&offset=${offset}`);
    const items = (json && json.issues) || [];
    out.push(...items);
    offset += 100;
    if (!json || offset >= (json.total_count || 0) || items.length === 0) break;
  }
  return out;
}

let _me = null;
async function me() {
  if (_me == null) _me = (await api('GET', '/users/current.json')).json.user.id;
  return _me;
}

// Resolve an --assign/assign value to a Redmine assigned_to_id:
//   'me' -> my id, 'none' -> null (unassign),
//   a plural TYPE GROUP ('ai-writers', ...) -> that group's id  (NEW/available work: a free slot claims it),
//   a specific login/role/'maciej' -> its user id (USERS)       (active work handed to one slot),
//   else a raw numeric id.
async function resolveAssignee(who) {
  if (who === 'none') return null;
  if (who === 'me') return me();
  const key = String(who).toLowerCase();
  if (GROUPS[key] != null) return GROUPS[key];
  const known = USERS[key];
  if (known != null) return known;
  const n = Number(who);
  if (Number.isNaN(n)) die(`unknown assignee "${who}" -- use me|none|<user_id>|a group ${Object.keys(GROUPS).join('|')}|or ${Object.keys(USERS).join('|')}`);
  return n;
}

// Resolve a project to its numeric id: numeric -> as-is; known name -> map; else look up via API.
let _projCache = null;
async function resolveProject(v) {
  if (v == null || v === true) die('--project required');
  if (/^\d+$/.test(String(v))) return Number(v);
  const k = String(v).toLowerCase().replace(/[\s-]/g, '_');
  if (PROJECTS[k] != null) return PROJECTS[k];
  if (!_projCache) _projCache = (await api('GET', '/projects.json?limit=200')).json.projects || [];
  const lc = String(v).toLowerCase();
  const hit = _projCache.find(p => p.identifier === lc || p.identifier === k || p.name.toLowerCase() === lc);
  if (hit) return hit.id;
  die(`unknown project: "${v}"`);
}

// ---------------- remote state (in a Redmine issue's description) ----------------
let _stateIssueId = null;
async function findStateIssue() {
  // Find by marker subject; fall back to a bounded project scan if the ~filter is unsupported.
  let hits = await paginate(`/issues.json?project_id=${STATE_PROJECT}&status_id=*&subject=${encodeURIComponent('~' + STATE_SUBJECT)}`);
  let hit = hits.find(i => i.subject === STATE_SUBJECT);
  if (!hit) {
    hits = await paginate(`/issues.json?project_id=${STATE_PROJECT}&status_id=*&sort=id:desc`);
    hit = hits.find(i => i.subject === STATE_SUBJECT);
  }
  return hit ? hit.id : null;
}
function wrapState(obj) {
  return `This issue stores state for redmine.js (the \`inbox\` command). Do not delete or edit the block below.\n\n` +
    `${STATE_BEGIN}\n${JSON.stringify(obj)}\n${STATE_END}\n`;
}
async function loadState() {
  const id = await findStateIssue();
  if (!id) return null;            // no state issue yet -> first run
  _stateIssueId = id;
  const desc = (await api('GET', `/issues/${id}.json`)).json.issue.description || '';
  const a = desc.indexOf(STATE_BEGIN), b = desc.indexOf(STATE_END);
  if (a === -1 || b === -1) return { __id: id };  // issue exists but no parseable state
  try { const o = JSON.parse(desc.slice(a + STATE_BEGIN.length, b).trim()); o.__id = id; return o; }
  catch (_) { return { __id: id }; }
}
async function saveState(obj) {
  const id = obj.__id || _stateIssueId;
  const clean = { ...obj }; delete clean.__id;
  const desc = wrapState(clean);
  if (id) { await api('PUT', `/issues/${id}.json`, { issue: { description: desc } }); return id; }
  const created = (await api('POST', '/issues.json', {
    issue: { project_id: STATE_PROJECT, tracker_id: TRACKERS.zadanie, subject: STATE_SUBJECT, description: desc },
  })).json.issue;
  _stateIssueId = created.id;
  return created.id;
}

// ---------------- arg parsing ----------------
function parseArgs(argv) {
  const positional = [], flags = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const eq = a.indexOf('=');
      if (eq !== -1) flags[a.slice(2, eq)] = a.slice(eq + 1);
      else if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) flags[a.slice(2)] = argv[++i];
      else flags[a.slice(2)] = true;
    } else positional.push(a);
  }
  return { positional, flags };
}
// Per-command allowed flags. Derived from the actual `flags.X` / `flags['X']` reads in each
// command below -- keep in sync when adding a flag. Unknown flags used to be silently ignored,
// which threw away content without any signal: `update --notes "..."` (the flag is `--note`)
// dropped the comment while still applying the other field changes and reporting success.
// That cost real work on 2026-09-02 -- five comments lost, two of them answers to Maciej,
// and reassignment in the same call revoked visibility so they could not be re-posted in place
// (COI #46051). Rejecting unknown flags kills the whole class, including the sibling reports
// for `--desc-file` (COI #45147) and `--assign` on `list`.
const ALLOWED_FLAGS = {
  whoami: [], meta: [], projects: [],
  list: ['author', 'available', 'created', 'json', 'mine', 'nowy', 'project', 'raw', 'status', 'subject', 'tracker', 'updated'],
  curate: ['json'],
  show: ['json'],
  create: ['assign', 'dedup', 'desc', 'desc-file', 'json', 'priority', 'project', 'subject', 'tags', 'tracker'],
  comment: [], status: [], close: [], tag: [], addtag: [], rmtag: [], claim: [], release: [],
  'inbox-gc': ['days'],
  inbox: ['all', 'json'],
  update: ['assign', 'desc', 'desc-file', 'done', 'note', 'parent', 'priority', 'project', 'status', 'subject', 'tracker'],
  assign: [],
  attach: ['desc', 'note', 'type'],
  plan: ['assign', 'date', 'desc', 'desc-file', 'dry', 'focus', 'no-pdf', 'pdf', 'project', 'subject', 'tags'],
  note: [], log: [],
  relate: ['delay'], relations: [], unrelate: [],
  recur: ['days', 'monthdays', 'months', 'time', 'tracker', 'years', 'every'], unrecur: ['issue'], schedules: ['json'],
  reschedule: ['days', 'monthdays', 'months', 'time', 'years', 'every'],
  search: ['all-types', 'all-words', 'closed', 'json', 'limit', 'open', 'project', 'subprojects', 'titles', 'wiki'],
  'wiki-list': ['json', 'project'],
  'wiki-get': ['json', 'project'],
  'wiki-put': ['comment', 'file', 'parent', 'project', 'text'],
  'wiki-del': ['project'],
};

function _editDistance(a, b) {
  const m = a.length, n = b.length;
  let prev = Array.from({ length: n + 1 }, (_, j) => j);
  for (let i = 1; i <= m; i++) {
    const cur = [i];
    for (let j = 1; j <= n; j++) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    }
    prev = cur;
  }
  return prev[n];
}

// Reject unknown flags loudly instead of silently discarding them.
function validateFlags(cmd, flags) {
  const allowed = ALLOWED_FLAGS[cmd];
  if (!allowed) return; // command not in the map -> don't guess, stay permissive
  const set = new Set(allowed);
  for (const key of Object.keys(flags)) {
    if (set.has(key)) continue;
    // closest legal flag for THIS command
    let best = null, bestD = Infinity;
    for (const cand of allowed) {
      const d = _editDistance(key, cand);
      if (d < bestD) { bestD = d; best = cand; }
    }
    let msg = `unknown flag --${key} for '${cmd}'`;
    if (best && bestD <= 3) msg += ` (did you mean --${best}?)`;
    // if it is a real flag but on a different command, say so -- that is the other common slip
    const elsewhere = Object.keys(ALLOWED_FLAGS).filter(c => c !== cmd && ALLOWED_FLAGS[c].includes(key));
    if (elsewhere.length) msg += ` -- --${key} is valid on: ${elsewhere.join(', ')}`;
    msg += `\n  allowed for '${cmd}': ${allowed.length ? allowed.map(f => '--' + f).join(' ') : '(none)'}`;
    die(msg);
  }
}

function tagsFromJournals(issue) {
  let tags = null;
  for (const j of issue.journals || []) for (const d of j.details || []) if (d.name === 'tag_list') tags = d.new_value;
  return tags;
}

// ---------------- commands ----------------
const cmds = {};

cmds.whoami = async () => {
  const u = (await api('GET', '/users/current.json')).json.user;
  console.log(`#${u.id}  ${u.login}  (${[u.firstname, u.lastname].filter(Boolean).join(' ')})  ${u.mail || ''}`.trim());
  // Identity guard. The keys are near-identical 40-char hex strings; booting with the wrong one
  // writes into another type's memory. Fail loudly rather than silently. (Only when REDMINE_AGENT
  // is set — bootstrap always sets it to your self-discovered ai-<role>-<slot>.)
  if (AGENT && u.login !== AGENT) {
    console.error(`\n!! IDENTITY MISMATCH: REDMINE_AGENT=${AGENT} but this API key belongs to '${u.login}'.`);
    console.error('!! STOP — using the wrong key corrupts another type\'s memory. Fix REDMINE_API_KEY (or REDMINE_AGENT).');
    process.exitCode = 1;
    return;
  }
  console.log(`agent: ${AGENT || u.login} | memory project: ${MEMORY_PROJECT || '?'} | inbox-state issue -> project ${STATE_PROJECT}`);
};

cmds.meta = async () => {
  const show = (name, m) => {
    const seen = new Map();
    for (const [k, v] of Object.entries(m)) if (!seen.has(v)) seen.set(v, k);
    console.log(`${name}: ` + [...seen].map(([v, k]) => `${k}=${v}`).join(', '));
  };
  show('projects', PROJECTS); show('trackers', TRACKERS); show('statuses', STATUSES); show('priorities', PRIORITIES);
};

cmds.projects = async () => {
  ((await api('GET', '/projects.json?limit=100')).json.projects || [])
    .forEach(p => console.log(`${p.id}\t${p.identifier}\t${p.name}`));
};

cmds.list = async (args) => {
  const { flags } = parseArgs(args);
  const parts = [];
  if (flags.project) parts.push(`project_id=${await resolveProject(flags.project)}`);
  const status = flags.nowy ? 'nowy' : (flags.status || 'open'); // --nowy = shorthand for the curation-only Nowy queue
  if (status === 'all') parts.push('status_id=*');
  else if (status !== 'open') parts.push(`status_id=${resolve(STATUSES, status, 'status')}`);
  if (flags.tracker) parts.push(`tracker_id=${resolve(TRACKERS, flags.tracker, 'tracker')}`);
  if (flags.author) parts.push(`author_id=${flags.author === 'me' ? await me() : flags.author}`);
  if (flags.subject) parts.push(`subject=${encodeURIComponent('~' + flags.subject)}`);
  if (flags.created) parts.push(`created_on=${encodeURIComponent(flags.created)}`);
  if (flags.updated) parts.push(`updated_on=${encodeURIComponent(flags.updated)}`);
  if (flags.raw) parts.push(flags.raw);
  // --available: up-for-grabs work assigned to MY type group (claim one with: assign <id> me).
  if (flags.available) {
    const g = GROUPS[`ai-${ROLE}s`];
    if (!g) die('--available needs a known role (boot as ai-<role>-<slot>)');
    parts.push(`assigned_to_id=${g}`);
  } else if (flags.mine || (!flags.project && !flags.author && !flags.raw)) {
    parts.push(`assigned_to_id=${await me()}`);
  }
  const issues = await paginate('/issues.json?' + parts.join('&') + '&sort=updated_on:desc');
  if (flags.json) return console.log(JSON.stringify(issues, null, 2));
  issues.forEach(i => console.log(`#${i.id}  [${i.project.name}/${i.tracker.name}/${i.status.name}]  ${i.subject}`));
  console.log(`(${issues.length} issues)`);
};

// Curation view: the Nowy (status_id=1) queue across LEAF WORK projects only.
// Karafka 73 is a NORMAL leaf now (full access since 2026-07-14; the old scoping rule is dead).
// NEVER curate the AI-Limited projects 58 (Zycie) / 71 (Jezdziecka): I only see cards assigned to me there,
// so an empty result means "nothing assigned", NOT "empty queue".
// NEVER enumerate a PARENT project -- 82 (Development) and 92 (AIs) fan out into their
// subprojects (incl. every type's private memory).
// Type MEMORY projects (ai-<role>s) are not work queues and are never curated.
const CURATE_BY_ROLE = {
  pm: [
    [73, "Karafka"], [84, "Ruby"], [85, "Shoryuken"], [86, "Other"], [87, "Social"], [88, "Bugs"],
    [90, "COI"],
  ],
  researcher: [ [84, "Ruby"], [90, "COI"], [86, "Other"] ],
  writer: [ [87, "Social"], [86, "Other"] ],
  coder: [ [73, "Karafka"], [84, "Ruby"], [90, "COI"], [86, "Other"], [88, "Bugs"] ],
};
const CURATE_LEAVES = CURATE_BY_ROLE[ROLE] || [];
cmds.curate = async (args) => {
  const { flags } = parseArgs(args);
  let grand = 0;
  for (const [pid, name] of CURATE_LEAVES) {
    const issues = await paginate(`/issues.json?project_id=${pid}&status_id=1&sort=id:asc`);
    grand += issues.length;
    console.log(`\n== ${name} (${pid}) — ${issues.length} Nowy ==`);
    if (flags.json) continue;
    issues.forEach(i => console.log(`#${i.id}  [${i.tracker.name}]  ${i.subject}`));
  }
  console.log(`\n(total ${grand} Nowy across leaves. NEVER enumerate a PARENT (82 Development / 92 AIs), a type memory project (ai-<role>s), or the AI-Limited projects (58 Zycie / 71 Jezdziecka). Verdicts per Triage-Criteria.)`);
};

cmds.show = async (args) => {
  const { positional, flags } = parseArgs(args);
  const id = positional[0] || die('usage: show <id>');
  const i = (await api('GET', `/issues/${id}.json?include=journals,relations,attachments,children`)).json.issue;
  if (flags.json) return console.log(JSON.stringify(i, null, 2));
  console.log(`#${i.id}  [${i.project.name}/${i.tracker.name}/${i.status.name}/${i.priority.name}]`);
  console.log(`subject : ${i.subject}`);
  console.log(`author  : ${i.author && i.author.name}    assignee: ${i.assigned_to ? i.assigned_to.name : '-'}`);
  const tags = tagsFromJournals(i); if (tags) console.log(`tags    : ${tags}`);
  console.log(`updated : ${i.updated_on}`);
  if (i.parent) console.log(`parent  : #${i.parent.id}`);
  if ((i.relations || []).length) console.log('relations: ' + i.relations.map(r => `${r.relation_type} #${r.issue_id === Number(id) ? r.issue_to_id : r.issue_id}`).join(', '));
  if ((i.children || []).length) console.log('children: ' + i.children.map(c => `#${c.id} ${c.subject}`).join(', '));
  if ((i.attachments || []).length) console.log('attachments: ' + i.attachments.map(a => `${a.filename} (${a.filesize}B) ${a.content_url}`).join('  '));
  if (i.description) console.log('\n' + i.description + '\n');
  const comments = (i.journals || []).filter(j => j.notes && j.notes.trim());
  if (comments.length) {
    console.log('--- comments ---');
    comments.forEach(j => console.log(`[${j.created_on}] <${j.user.name}>\n${j.notes}\n`));
  }
};

cmds.create = async (args) => {
  const { flags } = parseArgs(args);
  if (flags.desc && flags['desc-file']) die('--desc and --desc-file are mutually exclusive');
  const issue = {
    project_id: await resolveProject(flags.project || die('--project required')),
    tracker_id: resolve(TRACKERS, flags.tracker || die('--tracker required'), 'tracker'),
    subject: flags.subject || die('--subject required'),
  };
  const desc = flags['desc-file'] ? fs.readFileSync(flags['desc-file'], 'utf8') : flags.desc;
  if (desc) issue.description = desc;
  if (flags.priority) issue.priority_id = resolve(PRIORITIES, flags.priority, 'priority');
  if (flags.assign) issue.assigned_to_id = await resolveAssignee(flags.assign);
  if (flags.dedup) {
    const ex = await paginate(`/issues.json?project_id=${issue.project_id}&status_id=*&subject=${encodeURIComponent('~' + issue.subject)}`);
    const dup = ex.find(e => e.subject === issue.subject);
    if (dup) return console.log(`exists: #${dup.id} (dedup)`);
  }
  const created = (await api('POST', '/issues.json', { issue })).json.issue;
  if (flags.tags) await api('PUT', `/issues/${created.id}.json`, { issue: { tag_list: String(flags.tags).split(',').map(s => s.trim()) } });
  if (flags.json) return console.log(JSON.stringify(created, null, 2));
  console.log(`created #${created.id}  ${created.subject}`);
};

cmds.comment = async (args) => {
  const { positional } = parseArgs(args);
  const id = positional[0] || die('usage: comment <id> "text"');
  const note = positional.slice(1).join(' ') || die('comment text required');
  await api('PUT', `/issues/${id}.json`, { issue: { notes: note } });
  console.log(`commented on #${id}`);
};

async function setStatus(id, statusId, note) {
  const body = { issue: { status_id: statusId } };
  if (note) body.issue.notes = note;
  await api('PUT', `/issues/${id}.json`, body);
  if (statusId === 7) { // Nowy->Sprawdzony is sometimes silently rejected; verify + two-step
    const now = (await api('GET', `/issues/${id}.json`)).json.issue.status.id;
    if (now !== 7) {
      await api('PUT', `/issues/${id}.json`, { issue: { status_id: 5 } });
      await api('PUT', `/issues/${id}.json`, { issue: { status_id: 7 } });
    }
  }
}

cmds.status = async (args) => {
  const { positional } = parseArgs(args);
  const id = positional[0] || die('usage: status <id> <status> ["note"]');
  const want = resolve(STATUSES, positional[1] || die('status required'), 'status');
  await setStatus(id, want, positional.slice(2).join(' ') || null);
  const now = (await api('GET', `/issues/${id}.json`)).json.issue.status;
  console.log(`#${id} -> ${now.name}`);
  if (now.id !== want) console.error(`warning: status is "${now.name}" (id ${now.id}), not requested id ${want} — this project's workflow may not allow that transition for your role/tracker.`);
};

cmds.close = async (args) => {
  const { positional } = parseArgs(args);
  const id = positional[0] || die('usage: close <id> ["note"]');
  await setStatus(id, 5, positional.slice(1).join(' ') || null);
  console.log(`#${id} -> closed`);
};

cmds.tag = async (args) => {
  const { positional } = parseArgs(args);
  const id = positional[0] || die('usage: tag <id> a,b,c');
  const tags = positional.slice(1).join(',').split(',').map(s => s.trim()).filter(Boolean);
  await api('PUT', `/issues/${id}.json`, { issue: { tag_list: tags } });
  console.log(`#${id} tags -> ${tags.join(', ')}`);
};

async function getTags(id) {
  const tl = tagsFromJournals((await api('GET', `/issues/${id}.json?include=journals`)).json.issue);
  return tl ? tl.split(',').map(s => s.trim()).filter(Boolean) : [];
}
// Additive tag ops (read-merge-write) — safer than `tag` (replace-all) when sessions run in parallel.
cmds.addtag = async (args) => {
  const { positional } = parseArgs(args);
  const id = positional[0] || die('usage: addtag <id> a,b');
  const tags = [...new Set([...(await getTags(id)), ...positional.slice(1).join(',').split(',').map(s => s.trim()).filter(Boolean)])];
  await api('PUT', `/issues/${id}.json`, { issue: { tag_list: tags } });
  console.log(`#${id} tags -> ${tags.join(', ')}`);
};
cmds.rmtag = async (args) => {
  const { positional } = parseArgs(args);
  const id = positional[0] || die('usage: rmtag <id> a,b');
  const rm = new Set(positional.slice(1).join(',').split(',').map(s => s.trim()).filter(Boolean));
  const tags = (await getTags(id)).filter(t => !rm.has(t));
  await api('PUT', `/issues/${id}.json`, { issue: { tag_list: tags } });
  console.log(`#${id} tags -> ${tags.join(', ') || '(none)'}`);
};
// Cooperative work-claiming for parallel SESSIONS of the SAME agent (same user, so the assignee
// cannot disambiguate them -> claim by tag + comment). Between DIFFERENT agents use assignment.
cmds.claim = async (args) => {
  const { positional } = parseArgs(args);
  const id = positional[0] || die('usage: claim <id> ["note"]');
  const note = positional.slice(1).join(' ');
  const tags = [...new Set([...(await getTags(id)), 'wip', `wip-${SESSION}`])];
  await api('PUT', `/issues/${id}.json`, { issue: { tag_list: tags, notes: `[wip] claimed by session ${SESSION}${note ? ' — ' + note : ''}` } });
  console.log(`#${id} claimed by ${SESSION}`);
};
cmds.release = async (args) => {
  const { positional } = parseArgs(args);
  const id = positional[0] || die('usage: release <id> ["note"]');
  const note = positional.slice(1).join(' ');
  const tags = (await getTags(id)).filter(t => t !== 'wip' && t !== `wip-${SESSION}`);
  await api('PUT', `/issues/${id}.json`, { issue: { tag_list: tags, notes: `[released] by session ${SESSION}${note ? ' — ' + note : ''}` } });
  console.log(`#${id} released by ${SESSION}`);
};
// Close stale per-agent inbox-state issues (keeps the per-agent model tidy — e.g. a retired slot).
cmds['inbox-gc'] = async (args) => {
  const { flags } = parseArgs(args);
  const days = Number(flags.days || 30);
  const cutoff = Date.now() - days * 86400e3;
  const all = await paginate(`/issues.json?project_id=${STATE_PROJECT}&status_id=open&subject=${encodeURIComponent('~' + STATE_SUBJECT_PREFIX)}`);
  let n = 0;
  for (const i of all) {
    if (i.subject === STATE_SUBJECT) continue;
    if (new Date(i.updated_on).getTime() < cutoff) { await setStatus(i.id, 5, `stale session state (>${days}d) — closed by inbox-gc`); n++; }
  }
  console.log(`closed ${n} stale state issue(s) older than ${days}d.`);
};

// Detect NEW comments by OTHERS on issues you authored or are assigned to. State lives in Redmine.
cmds.inbox = async (args) => {
  const { flags } = parseArgs(args);
  const myId = await me();
  const state = await loadState();
  const hasState = state && Array.isArray(state.seen);
  const firstRun = !hasState;
  const seen = new Set(hasState ? state.seen : []);
  const stateIssueId = (state && state.__id) || _stateIssueId;
  const since = (hasState && !flags.all && state.last_check) ? state.last_check.slice(0, 10) : null;

  const byId = new Map();
  for (const f of [`author_id=${myId}`, `assigned_to_id=${myId}`]) {
    let q = `/issues.json?${f}&status_id=*`;
    if (since) q += `&updated_on=${encodeURIComponent('>=' + since)}`;
    for (const i of await paginate(q)) byId.set(i.id, i);
  }

  const fresh = [];
  for (const i of byId.values()) {
    if (i.id === stateIssueId) continue;             // skip the state issue itself
    const full = (await api('GET', `/issues/${i.id}.json?include=journals`)).json.issue;
    for (const j of full.journals || []) {
      if (!j.notes || !j.notes.trim()) continue;     // not a comment (e.g. field change)
      if (j.user && j.user.id === myId) continue;     // mine
      if (seen.has(j.id)) continue;                   // already reported
      fresh.push({ issue_id: i.id, subject: i.subject, journal_id: j.id, user: j.user && j.user.name, created_on: j.created_on, notes: j.notes });
      seen.add(j.id);
    }
  }

  await saveState({ __id: stateIssueId, user_id: myId, last_check: new Date().toISOString(), seen: [...seen].slice(-8000) });

  if (firstRun) {
    console.log(`inbox initialised for agent "${AGENT || SESSION}": baselined ${fresh.length} existing comment(s) by others (none reported on first run). State issue: #${_stateIssueId}. This only happens once per agent now (state persists across ephemeral containers) -- if you see this on what you think is a later run, check REDMINE_AGENT is set.`);
    return;
  }
  if (flags.json) return console.log(JSON.stringify(fresh, null, 2));
  if (!fresh.length) return console.log(`no new comments. (agent ${AGENT || SESSION}, state #${_stateIssueId})`);
  fresh.sort((a, b) => a.created_on.localeCompare(b.created_on));
  console.log(`${fresh.length} new comment(s):\n`);
  for (const c of fresh) {
    console.log(`#${c.issue_id}  ${c.subject}`);
    console.log(`  [${c.created_on}] <${c.user}>: ${c.notes.replace(/\s+/g, ' ').slice(0, 500)}\n`);
  }
};

// Generic field update. For status->Sprawdzony use `status` (handles the workflow two-step).
cmds.update = async (args) => {
  const { positional, flags } = parseArgs(args);
  const id = positional[0] || die('usage: update <id> [--subject ..] [--desc ..|--desc-file f] [--priority p] [--assign me|none|<agent>|<id>] [--tracker t] [--status s] [--done N] [--project P] [--parent ID|none] [--note "text"]');
  if (flags.desc && flags['desc-file']) die('--desc and --desc-file are mutually exclusive');
  const issue = {};
  if (flags.subject) issue.subject = flags.subject;
  const desc = flags['desc-file'] ? fs.readFileSync(flags['desc-file'], 'utf8') : flags.desc;
  if (desc) issue.description = desc;
  if (flags.priority) issue.priority_id = resolve(PRIORITIES, flags.priority, 'priority');
  if (flags.tracker) issue.tracker_id = resolve(TRACKERS, flags.tracker, 'tracker');
  if (flags.status) issue.status_id = resolve(STATUSES, flags.status, 'status');
  if (flags.assign != null) { const uid = await resolveAssignee(flags.assign); issue.assigned_to_id = uid === null ? '' : uid; }
  if (flags.done != null) issue.done_ratio = Number(flags.done);
  if (flags.project) issue.project_id = await resolveProject(flags.project);
  if (flags.parent != null) issue.parent_issue_id = flags.parent === 'none' ? '' : Number(flags.parent);
  if (flags.note) issue.notes = flags.note;
  if (!Object.keys(issue).length) die('nothing to update — pass at least one field flag');
  await api('PUT', `/issues/${id}.json`, { issue });
  console.log(`updated #${id}: ${Object.keys(issue).join(', ')}`);
};
cmds.assign = async (args) => {
  const { positional } = parseArgs(args);
  const id = positional[0] || die('usage: assign <id> me|none|<group>|<login>|<user_id>');
  const who = positional[1] || die('usage: assign <id> me|<user_id>|none');
  const uid = await resolveAssignee(who);
  await api('PUT', `/issues/${id}.json`, { issue: { assigned_to_id: uid === null ? '' : uid } });
  // VERIFY. Redmine silently DROPS assigned_to_id if that user is not a member of the
  // issue's project -- the PUT still succeeds (204). Without this check we would report
  // "routed to X" while the issue actually went nowhere.
  const after = (await api('GET', `/issues/${id}.json`)).json.issue;
  const got = after.assigned_to ? after.assigned_to.id : null;
  if (got !== uid) {
    console.error(`!! ASSIGN DID NOT TAKE on #${id}: asked for ${uid === null ? 'none' : uid}, issue is ${got === null ? 'unassigned' : `assigned to ${after.assigned_to.name} (${got})`}.`);
    console.error(`!! Almost certainly the target user is NOT A MEMBER of project "${after.project.name}" (${after.project.id}). Redmine drops the field silently. Add the membership, then retry.`);
    process.exitCode = 1;
    return;
  }
  console.log(`#${id} -> ${uid === null ? 'unassigned' : `assigned to ${after.assigned_to.name} (${got})`}`);
};
async function uploadFile(file) {
  const data = fs.readFileSync(file);
  const name = path.basename(file);
  const res = await fetch(`${BASE}/uploads.json?filename=${encodeURIComponent(name)}`, {
    method: 'POST', headers: { 'X-Redmine-API-Key': KEY, 'Content-Type': 'application/octet-stream' }, body: data });
  if (!res.ok) die(`upload failed: HTTP ${res.status}`);
  return { token: (await res.json()).upload.token, filename: name };
}
// Upload a file and attach it to an issue (optionally with a description + a comment).
async function attachFile(id, file, contentType, desc, note) {
  const up = await uploadFile(file);
  const upload = { token: up.token, filename: up.filename, content_type: contentType || 'application/octet-stream' };
  if (desc) upload.description = desc;
  const issue = { uploads: [upload] };
  if (note) issue.notes = note;
  await api('PUT', `/issues/${id}.json`, { issue });
  return up.filename;
}
cmds.attach = async (args) => {
  const { positional, flags } = parseArgs(args);
  const id = positional[0] || die('usage: attach <id> <file> [--type ct] [--desc ..] [--note ..]');
  const name = await attachFile(id, positional[1] || die('file required'), flags.type, flags.desc, flags.note);
  console.log(`attached ${name} to #${id}`);
};

// One-shot workout/session plan delivery: HTML -> PDF (canonical wkhtmltopdf) -> find/create the dated
// card -> attach both. Removes the per-session ritual (remembering the flag chain + create + double-attach).
// Template skeleton lives at /workspace/templates/plan.html (persists to host).
const WKHTMLTOPDF_FLAGS = ['--enable-local-file-access', '--page-size', 'A4',
  '--margin-top', '10mm', '--margin-bottom', '10mm', '--margin-left', '12mm', '--margin-right', '12mm',
  '--encoding', 'utf-8'];
cmds.plan = async (args) => {
  const { positional, flags } = parseArgs(args);
  const html = positional[0] || die('usage: plan <html-file> --project P --date DD.MM.YYYY [--focus "..."] [--subject "..."] [--desc ..|--desc-file f] [--pdf out] [--no-pdf] [--tags a,b] [--assign me|id] [--dry]');
  if (!fs.existsSync(html)) die(`html file not found: ${html}`);
  const pid = await resolveProject(flags.project || die('--project required'));
  const date = flags.date || die('--date DD.MM.YYYY required');
  const subject = flags.subject || `[${date}] ${flags.focus || ''}`.trim();
  let desc = flags.desc;
  if (flags['desc-file']) desc = fs.readFileSync(flags['desc-file'], 'utf8');

  // 1) render PDF (canonical flags) unless suppressed
  let pdf = null;
  if (!flags['no-pdf']) {
    pdf = (flags.pdf && flags.pdf !== true) ? flags.pdf : html.replace(/\.html?$/i, '') + '.pdf';
    try { execFileSync('wkhtmltopdf', [...WKHTMLTOPDF_FLAGS, html, pdf], { stdio: 'ignore' }); }
    catch (e) { die(`wkhtmltopdf failed (installed? 'sudo apt-get install -y wkhtmltopdf'): ${(e && e.message) || e}`); }
  }

  // 2) find the dated card (exact subject) or note that we'd create it
  const existing = await findBySubject(pid, subject);
  if (flags.dry) {
    console.log(`[dry] project ${pid} | subject: ${subject}`);
    console.log(`[dry] pdf: ${pdf || '(skipped)'}${pdf ? ' (' + (fs.existsSync(pdf) ? fs.statSync(pdf).size + 'B' : 'NOT RENDERED') + ')' : ''}`);
    console.log(`[dry] would ${existing ? `attach to existing #${existing}` : 'CREATE a new card'} + attach ${path.basename(html)}${pdf ? ' + ' + path.basename(pdf) : ''}`);
    return;
  }
  let id = existing, createdNew = false;
  if (!id) {
    const issue = { project_id: pid, tracker_id: TRACKERS.zadanie, subject };
    if (desc) issue.description = desc;
    issue.assigned_to_id = flags.assign ? await resolveAssignee(flags.assign) : await me();
    id = (await api('POST', '/issues.json', { issue })).json.issue.id;
    const tags = (flags.tags ? String(flags.tags) : '').split(',').map((s) => s.trim()).filter(Boolean);
    await api('PUT', `/issues/${id}.json`, { issue: { tag_list: tags } });
    createdNew = true;
  } else if (desc) {
    await api('PUT', `/issues/${id}.json`, { issue: { description: desc } });
  }

  // 3) attach HTML (+ PDF)
  await attachFile(id, html, 'text/html', 'Karta do druku (HTML)');
  if (pdf) await attachFile(id, pdf, 'application/pdf', 'Karta do druku (PDF)');
  console.log(`plan -> #${id} ${createdNew ? '(created)' : '(existing)'} · ${subject}`);
  console.log(`attached: ${path.basename(html)}${pdf ? ' + ' + path.basename(pdf) : ''}`);
};

// ---------------- memory: notes & session journal (append-only = parallel-safe) ----------------
const NOTE_TARGETS = { karafka: 41163, ruby: 41164, coi: 41165, backlog: 41162, tool: 41162 }; // ai-pm (91) notes issues
async function findBySubject(pid, subject) {
  const hits = await paginate(`/issues.json?project_id=${pid}&status_id=*&subject=${encodeURIComponent('~' + subject)}`);
  return (hits.find(i => i.subject === subject) || {}).id || null;
}
cmds.note = async (args) => {
  const { positional } = parseArgs(args);
  const target = positional[0] || die(`usage: note <${Object.keys(NOTE_TARGETS).join('|')}|#id> "text"`);
  const text = positional.slice(1).join(' ') || die('note text required');
  const key = target.toLowerCase().replace(/^#/, '');
  const id = NOTE_TARGETS[key] || (/^\d+$/.test(key) ? Number(key) : die(`unknown note target: ${target}`));
  await api('PUT', `/issues/${id}.json`, { issue: { notes: text } });
  console.log(`noted on #${id}`);
};
cmds.log = async (args) => {
  const text = parseArgs(args).positional.join(' ') || die('usage: log "text"');
  const who = AGENT || 'agent';
  const subj = `[log] ${who}`;                 // per-slot; rotates by closing (a fresh OPEN one is made when the old closes)
  const open = await paginate(`/issues.json?project_id=${STATE_PROJECT}&status_id=open&subject=${encodeURIComponent('~' + subj)}`);
  let id = (open.find((i) => i.subject === subj) || {}).id;
  if (!id) id = (await api('POST', '/issues.json', { issue: { project_id: STATE_PROJECT, tracker_id: TRACKERS.zadanie, subject: subj, assigned_to_id: await me(), description: `Rotating per-slot log for ${who}. Append-only comments; close it every week or two and a fresh one opens automatically. Issues are never deleted.` } })).json.issue.id;
  await api('PUT', `/issues/${id}.json`, { issue: { notes: `(${SESSION}) ${text}` } });
  console.log(`logged to #${id} (${subj})`);
};

// ---------------- relations ----------------
const REL_TYPES = ['relates', 'duplicates', 'duplicated', 'blocks', 'blocked', 'precedes', 'follows', 'copied_to', 'copied_from'];
cmds.relate = async (args) => {
  const { positional, flags } = parseArgs(args);
  const [id, type, other] = positional;
  if (!id || !type || !other) die(`usage: relate <id> <${REL_TYPES.join('|')}> <other_id> [--delay N]`);
  if (!REL_TYPES.includes(type)) die('relation must be one of: ' + REL_TYPES.join(', '));
  const relation = { issue_to_id: Number(other), relation_type: type };
  if (flags.delay) relation.delay = Number(flags.delay);
  const r = await api('POST', `/issues/${id}/relations.json`, { relation });
  console.log(`#${id} ${type} #${other}  (relation ${r.json.relation.id})`);
};
cmds.relations = async (args) => {
  const { positional } = parseArgs(args);
  const id = positional[0] || die('usage: relations <id>');
  const rels = (await api('GET', `/issues/${id}/relations.json`)).json.relations || [];
  if (!rels.length) return console.log('(no relations)');
  rels.forEach(x => console.log(`rel#${x.id}  #${x.issue_id} ${x.relation_type} #${x.issue_to_id}${x.delay ? ` (delay ${x.delay})` : ''}`));
};
cmds.unrelate = async (args) => {
  const { positional } = parseArgs(args);
  const rid = positional[0] || die('usage: unrelate <relation_id>');
  await api('DELETE', `/relations/${rid}.json`);
  console.log(`deleted relation ${rid}`);
};

// ---------------- recurring tasks (redmine_recurring_tasks with Maciej's JSON API patch) ----------------
const DAYMAP = { mon: 'monday', tue: 'tuesday', wed: 'wednesday', thu: 'thursday', fri: 'friday', sat: 'saturday', sun: 'sunday' };
// --every 1h | 90m | 1h30m | 45 (plain number = minutes) -> interval_minutes, 5..1440 (plugin 0.5.0).
function parseEvery(v) {
  const s = String(v).trim().toLowerCase();
  const m = s.match(/^(?:(\d+)h)?(?:(\d+)m?)?$/);
  if (!s || !m || (m[1] === undefined && m[2] === undefined)) die(`bad --every: ${v} (e.g. 1h, 90m, 1h30m)`);
  const mins = Number(m[1] || 0) * 60 + Number(m[2] || 0);
  if (mins < 5 || mins > 1440) die(`--every must be 5 minutes to 24h (got ${mins} minutes)`);
  return mins;
}
// Builds the run-type part of a schedule from --every / --days / --monthdays / --months / --years.
// Week days, when sent, are all seven booleans, so a PUT replaces the old set instead of merging.
function scheduleFields(flags, { requireWhen }) {
  const monthdays = String(flags.monthdays || '').split(',').map(s => s.trim()).filter(Boolean);
  const days = String(flags.days || '').split(',').map(s => s.trim().toLowerCase()).filter(Boolean);
  const rt = {};
  if (flags.every) {
    rt.client_run_type = 'interval';
    rt.interval_minutes = parseEvery(flags.every);
  } else if (monthdays.length) rt.client_run_type = 'month_days';
  else if (days.length) rt.client_run_type = 'week_days';
  else if (requireWhen) die('provide --every (interval), --days (weekly) or --monthdays (monthly)');
  // Unsent filters are kept on a PUT; switching to weekly clears month days and vice versa.
  if (monthdays.length || rt.client_run_type === 'week_days') rt.month_days = monthdays;
  if (days.length || rt.client_run_type === 'month_days') {
    for (const k of Object.values(DAYMAP)) rt[k] = false;
    for (const d of days) { const k = DAYMAP[d] || (Object.values(DAYMAP).includes(d) ? d : null); if (!k) die(`bad day: ${d}`); rt[k] = true; }
  }
  if (flags.months) rt.months = String(flags.months).split(',').map(s => s.trim());
  // --years limits the schedule to those years (4 digits each); left out = every year.
  if (flags.years) {
    const years = String(flags.years).split(/[\s,;]+/).filter(Boolean);
    for (const y of years) if (!/^\d{4}$/.test(y)) die(`bad year: ${y} (use 4 digits, e.g. --years 2027)`);
    rt.years = years;
  }
  if (flags.time) rt.time = flags.time;
  return rt;
}
cmds.recur = async (args) => {
  const { positional, flags } = parseArgs(args);
  const issueId = positional[0] || die('usage: recur <issue_id> (--every 1h [--time HH:MM] | --time HH:MM --days mon,wed | --time HH:MM --monthdays 1,15) [--months 1..12] [--years 2027,2029] [--tracker T]');
  if (!flags.time && !flags.every) die('--time HH:MM required');
  const rt = scheduleFields(flags, { requireWhen: true });
  // Interval: --time is the first run of the day (server time, UTC); default 00:00 = from midnight.
  if (!rt.time) rt.time = '00:00';
  if (!rt.months) rt.months = ['1','2','3','4','5','6','7','8','9','10','11','12'];
  rt.tracker_id = resolve(TRACKERS, flags.tracker || 'zadanie_cykliczne', 'tracker');
  // JSON API (Maciej's plugin patch, 2026-10-13): 201 + {recurring_task}; 422 {errors} on validation
  // (e.g. a bad year, or the issue already has a schedule: one per issue); 404 unknown issue; 403 no :manage_schedule.
  const { json } = await api('POST', '/recurring_tasks.json', { issue_id: Number(issueId), recurring_task: rt });
  const t = (json && json.recurring_task) || {};
  console.log(`created on issue #${issueId}: ${fmtSchedule(t)}`);
  console.log(`remove it with: unrecur ${t.id}`);
};
// PUT keeps whatever is not sent. --every turns it into (or changes) an interval; --days/--monthdays
// without --every turn it back into a weekly/monthly schedule (the plugin clears interval_minutes).
cmds.reschedule = async (args) => {
  const { positional, flags } = parseArgs(args);
  const id = positional[0] || die('usage: reschedule <schedule_id> [--every 30m] [--time HH:MM] [--days ..|--monthdays ..] [--months ..] [--years ..]');
  const rt = scheduleFields(flags, { requireWhen: false });
  if (!Object.keys(rt).length) die('nothing to change: pass --every, --time, --days, --monthdays, --months or --years');
  const { json } = await api('PUT', `/recurring_tasks/${id}.json`, { recurring_task: rt });
  let t = json && json.recurring_task;
  if (!t) t = ((await api('GET', `/recurring_tasks/${id}.json`)).json || {}).recurring_task || {};
  console.log(`updated: ${fmtSchedule(t)}`);
};
function fmtSchedule(t) {
  const fmtEvery = (n) => (n >= 60 ? `${Math.floor(n / 60)}h` : '') + (n % 60 ? `${n % 60}m` : '');
  const filters = [(t.week_days || []).length ? `week-days ${t.week_days.join(',')}` : '', (t.month_days || []).length ? `month-days ${t.month_days.join(',')}` : ''].filter(Boolean).join(' ');
  const when = t.run_type === 'interval' ? `every ${fmtEvery(t.interval_minutes)} from ${t.time} ${filters || 'every day'}`
    : t.run_type === 'month_days' ? `month-days ${(t.month_days || []).join(',')}` : `week-days ${(t.week_days || []).join(',')}`;
  const months = (t.months || []).length && (t.months || []).length < 12 ? ` months ${t.months.join(',')}` : '';
  const years = (t.years || []).length ? ` years ${t.years.join(',')}` : ' every year';
  const at = t.run_type === 'interval' ? '' : ` @ ${t.time}`;
  return `schedule #${t.id}  issue #${t.issue_id}  ${when}${months}${years}${at}  last fired: ${t.last_try_at || 'never'}`;
}
cmds.schedules = async (args) => {
  const { positional, flags } = parseArgs(args);
  const issueId = positional[0] || die('usage: schedules <issue_id> [--json]');
  const { json } = await api('GET', `/recurring_tasks.json?issue_id=${encodeURIComponent(issueId)}`);
  const list = (json && json.recurring_tasks) || [];
  if (flags.json) return console.log(JSON.stringify(list, null, 2));
  if (!list.length) return console.log(`issue #${issueId} has no schedule`);
  for (const t of list) console.log(fmtSchedule(t));
};
cmds.unrecur = async (args) => {
  const { positional, flags } = parseArgs(args);
  let id = positional[0];
  if (!id && flags.issue) {
    const { json } = await api('GET', `/recurring_tasks.json?issue_id=${encodeURIComponent(flags.issue)}`);
    const t = ((json && json.recurring_tasks) || [])[0];
    if (!t) return console.log(`issue #${flags.issue} has no schedule; nothing to delete`);
    id = t.id;
  }
  if (!id) die('usage: unrecur <schedule_id> | unrecur --issue <issue_id>');
  await api('DELETE', `/recurring_tasks/${id}.json`);
  console.log(`deleted schedule #${id}`);
};

// Full-text search. Redmine matches each whitespace-separated query token as a case-insensitive
// SUBSTRING (LIKE %token%) over subject + description + notes/journals. So a full URL / PR link is
// a single token and matches the exact issue that carries it, out of the box - no special handling
// needed (dots and slashes are preserved, e.g. `search https://github.com/org/repo/pull/123`).
// Openness: default = open AND closed; --open = open only; --closed = closed only (Redmine has no
// closed-only param, but it tags each hit's type - "issue" vs "issue-closed" - so --closed filters to
// the "issue-closed" hits).
cmds.search = async (args) => {
  const { positional, flags } = parseArgs(args);
  const q = positional.join(' ');
  if (!q) die('usage: search <query...> [--project P [--subprojects]] [--open|--closed] [--wiki] [--titles] [--all-words] [--limit N] [--json]');
  if (flags.subprojects && !flags.project) die('--subprojects needs --project (it scopes a parent project to its subtree; global search already spans every project you can see)');
  if (flags.open && flags.closed) die('--open and --closed are mutually exclusive');
  const base = flags.project ? `/projects/${await resolveProject(flags.project)}/search.json` : '/search.json';
  const buildUrl = (extra) => {
    const qp = [`q=${encodeURIComponent(q)}`, `limit=${flags.limit || 25}`];
    if (flags.wiki) { qp.push('wiki_pages=1', 'issues=1'); }   // issues + wiki pages
    else if (!flags['all-types']) qp.push('issues=1');         // default: issues (see header note)
    if (flags.titles) qp.push('titles_only=1');                // match titles only, not body/notes
    if (flags['all-words']) qp.push('all_words=1');            // require every token (default is any)
    if (flags.subprojects) qp.push('scope=subprojects');       // parent -> whole subtree (visibility still applies)
    extra.forEach(e => qp.push(e));
    return `${base}?${qp.join('&')}`;
  };
  let results, total;
  if (flags.closed) {
    // Redmine has no closed_issues param, but search tags each hit's type: open issues come back as
    // "issue", closed ones as "issue-closed". So closed-only is just a type filter on one call.
    const all = (await api('GET', buildUrl([]))).json.results || [];
    results = all.filter(r => r.type === 'issue-closed');
    total = results.length;
  } else {
    const r = (await api('GET', buildUrl(flags.open ? ['open_issues=1'] : []))).json;
    results = r.results || [];
    total = r.total_count;
  }
  if (flags.json) return console.log(JSON.stringify(results, null, 2));
  results.forEach(x => console.log(`[${x.type}]  ${(x.title || '').replace(/\s+/g, ' ')}`));
  const note = flags.closed ? ' (closed only)' : '';
  console.log(`(${total} results${(total || 0) > results.length ? `, showing ${results.length}` : ''})${note}`);
};

// ---------------- wiki ----------------
cmds['wiki-list'] = async (args) => {
  const { flags } = parseArgs(args);
  const pid = await resolveProject(flags.project || die('--project required'));
  const pages = (await api('GET', `/projects/${pid}/wiki/index.json`)).json.wiki_pages || [];
  if (flags.json) return console.log(JSON.stringify(pages, null, 2));
  pages.forEach(p => console.log(`${p.title}  (v${p.version})${p.parent ? '  parent=' + p.parent.title : ''}`));
  console.log(`(${pages.length} pages)`);
};
cmds['wiki-get'] = async (args) => {
  const { positional, flags } = parseArgs(args);
  const title = positional[0] || die('usage: wiki-get <title> --project P [--json]');
  const pid = await resolveProject(flags.project || die('--project required'));
  const wp = (await api('GET', `/projects/${pid}/wiki/${encodeURIComponent(title)}.json`)).json.wiki_page;
  if (flags.json) return console.log(JSON.stringify(wp, null, 2));
  console.log(wp.text || '');
};
cmds['wiki-put'] = async (args) => {
  const { positional, flags } = parseArgs(args);
  const title = positional[0] || die('usage: wiki-put <title> --project P (--file path | --text "..." | stdin)');
  const pid = await resolveProject(flags.project || die('--project required'));
  let text = flags.text;
  if (flags.file) text = fs.readFileSync(flags.file === true ? die('--file needs a path') : flags.file, 'utf8');
  if (text == null) text = fs.readFileSync(0, 'utf8'); // stdin
  const body = { wiki_page: { text } };
  if (flags.comment) body.wiki_page.comments = flags.comment;
  if (flags.parent) body.wiki_page.parent_title = flags.parent;
  const r = await api('PUT', `/projects/${pid}/wiki/${encodeURIComponent(title)}.json`, body);
  console.log(`wiki ${r.status === 201 ? 'created' : 'updated'}: ${title}`);
};
cmds['wiki-del'] = async (args) => {
  const { positional, flags } = parseArgs(args);
  const title = positional[0] || die('usage: wiki-del <title> --project P');
  const pid = await resolveProject(flags.project || die('--project required'));
  await api('DELETE', `/projects/${pid}/wiki/${encodeURIComponent(title)}.json`);
  console.log(`wiki deleted: ${title}`);
};

const HELP = `redmine.js — Redmine CLI (state stored remotely in a Dev-project issue)

  whoami                                         the API key's user
  meta                                           known projects/trackers/statuses/priorities
  projects                                       list projects
  list [--project P] [--status S|open|all|--nowy] [--mine] [--available] [--tracker T] [--author me|id]
       (--available = up-for-grabs work assigned to MY type group; claim one with: assign <id> me)
       [--subject text] [--created EXPR] [--updated EXPR] [--raw "k=v&.."] [--json]
                                                 (--nowy = status_id=1 shorthand; the only queue curation touches)
  curate [--json]                                Nowy queue across MY role's LEAF WORK projects
                                                 (never a PARENT: 82 Development / 92 AIs; never AI-Limited 58/71;
                                                  never a type memory project: ai-<role>s)
  search <query...> [--project P [--subprojects]] [--open|--closed] [--wiki] [--titles] [--all-words] [--limit N] [--json]
                                                 full-text search (subject+desc+notes; incl. CLOSED issues by default).
                                                 Matching is case-insensitive SUBSTRING, so a full URL / PR link works
                                                 as-is (e.g. search https://github.com/org/repo/pull/123).
                                                 No --project = every project you can see (one call). --project P
                                                 --subprojects = that parent + its whole subtree. --open = open only;
                                                 --closed = closed only (dedup vs already-done work). Results are always
                                                 scoped to YOUR visibility (AI-Limited sees only cards assigned to you).
  show <id> [--json]                             issue details + comments
  create --project P --tracker T --subject "..." [--desc ..|--desc-file f] [--priority p] [--tags a,b] [--assign me|<agent>|<id>] [--dedup]
  update <id> [--subject ..][--desc ..|--desc-file f][--priority p][--assign me|none|<agent>|<id>][--tracker t][--status s][--done N][--project P][--parent ID|none][--note ..]
  assign <id> me|none|<group>|<login>|<user_id>  assign. NEW/available work -> a type GROUP (ai-pms|ai-coders|
                                                 ai-researchers|ai-writers|ai-curators|ai-butlers): the first free slot
                                                 claims it with: assign <id> me. Active work handed back -> a specific
                                                 slot (ai-<role>-<n>) or maciej. A bare role -> that role's slot 1.
  attach <id> <file> [--type ct] [--desc ..]     upload + attach a file
  plan <html> --project P --date DD.MM.YYYY [--focus ..][--subject ..][--desc ..|--desc-file f][--pdf out][--no-pdf][--tags a,b][--dry]
                                                 render HTML->PDF (wkhtmltopdf) + find/create dated card + attach both
  comment <id> "text"                            add a comment
  note <karafka|ruby|coi|backlog|#id> "text"     append to a memory notes issue
  log "text"                                     append to my rotating per-slot log issue ([log] <me>; close weekly to rotate)
  status <id> <status> ["note"]                  change status (Nowy->Sprawdzony handled; warns if rejected)
  close <id> ["note"]                            status <id> zamkniety
  tag <id> a,b,c                                 set tag_list (REPLACES all tags)
  addtag <id> a,b   /  rmtag <id> a,b            add/remove tags (read-merge; parallel-safe-ish)
  claim <id> ["note"]  /  release <id> ["note"]  LEGACY wip-tag claim; slots are distinct users now -> coordinate by assignment
  inbox [--all] [--json]                         NEW comments by others on your issues (PER-AGENT state, persists across ephemeral containers)
  inbox-gc [--days N]                            close stale per-agent inbox-state issues (default 30d)
  relate <id> <type> <other_id> [--delay N]      add a relation (relates|duplicates|blocks|precedes|...)
  relations <id>   /  unrelate <relation_id>     list / delete relations
  recur <issue_id> --time HH:MM (--days mon,wed | --monthdays 1,15) [--months ..] [--years 2027,..] [--tracker T]
                                                 create a recurring schedule (one per issue); prints its id;
                                                 --years = only in those years (default every year)
  recur <issue_id> --every 1h [--time HH:MM] [--days ..] [--monthdays ..] [--months ..] [--years ..]
                                                 interval: every 1h / 90m / 1h30m (5m..24h) from --time
                                                 (UTC, default 00:00) until midnight; days etc. filter
  reschedule <schedule_id> [--every ..] [--time ..] [--days ..|--monthdays ..] [--months ..] [--years ..]
                                                 change a schedule (unsent fields kept); --days/--monthdays
                                                 without --every switch an interval back to weekly/monthly
  schedules <issue_id> [--json]                  show the issue's schedule (id, when, years, last fired)
  unrecur <schedule_id> | unrecur --issue <id>   delete a schedule (by its id, or the issue's one)
  wiki-list --project P [--json]                 list wiki pages
  wiki-get <title> --project P [--json]          print a wiki page's text
  wiki-put <title> --project P (--file f | --text ".." | stdin) [--comment c] [--parent t]
                                                 create/update a wiki page
  wiki-del <title> --project P                   delete a wiki page

--project accepts a numeric id, a known name, or any project identifier/name (looked up via API).
Identity is self-discovered at boot: login ai-<role>-<slot>, memory = the type project ai-<role>s,
shared by every slot of the type. Types NEVER touch each other's memory - they coordinate through
TICKETS. Assignment model: route NEW/available work to a type GROUP (first free slot claims it with
assign <id> me; find it via list --available); hand ACTIVE work to a specific slot; only Maciej is
an individual person-assignee. Wiki/issue edits are last-write-wins - keep small.
env: REDMINE_API_KEY (required), REDMINE_AGENT (ai-<role>-<slot>), REDMINE_MEMORY_PROJECT (ai-<role>s),
     REDMINE_URL, REDMINE_SESSION, REDMINE_STATE_PROJECT, REDMINE_STATE_SUBJECT`;

(async () => {
  const [cmd, ...rest] = process.argv.slice(2);
  if (!cmd || ['help', '-h', '--help'].includes(cmd)) return console.log(HELP);
  if (!cmds[cmd]) die(`unknown command: ${cmd} (try: ${Object.keys(cmds).join(', ')})`);
  // A leftover REDMINE_STATE_PROJECT export (e.g. from before the multi-agent split, when
  // it pointed at the single shared memory project) silently redirects inbox state to another
  // agent's project -> 403. Warn loudly instead of failing silently (#43506).
  if (process.env.REDMINE_STATE_PROJECT && MEMORY_PROJECT && String(process.env.REDMINE_STATE_PROJECT) !== MEMORY_PROJECT) {
    console.error(`!! WARNING: REDMINE_STATE_PROJECT=${process.env.REDMINE_STATE_PROJECT} overrides the default for '${AGENT}' (memory ${MEMORY_PROJECT}). If this isn't deliberate, unset it -- it will misdirect 'inbox' state and can 403.`);
  }
  // REDMINE_AGENT should be self-discovered at boot (ai-<role>-<slot>; see the Kickoff/Bootstrap).
  // Without it, ROLE/MEMORY_PROJECT can't be derived and 'inbox'/'note'/'curate' won't know your
  // type project -> likely 403. Warn loudly instead of failing cryptically.
  if (!process.env.REDMINE_AGENT) {
    console.error(`!! WARNING: REDMINE_AGENT is not set. Identity should be self-discovered at boot (ai-<role>-<slot>). Without it, 'inbox'/'note'/'curate' can't resolve your type memory project and may 403.`);
  }
  // Validate flags before running: unknown flags are rejected rather than silently ignored.
  // Parsed separately here so each command keeps its own parseArgs call unchanged.
  validateFlags(cmd, parseArgs(rest).flags);
  await cmds[cmd](rest);
})().catch(e => die(e && e.message ? e.message : String(e)));





