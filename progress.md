# progress.md: CareRoute shared tracker

**Last updated:** 2026-10-17 by Sethika
**Deadline:** hacking 9:00 AM to 5:30 PM, Sat 17 Oct 2026. **Feature freeze 4:45 PM.** Submit (GitHub link, demo video, description) before 5:30 PM.
Read with `plan.md`, `README.md` and `skill.md`.

---

## 1. Agent rules (read first, every time)
1. **Read this whole file before starting any work**, then `git pull`.
2. **Claim before you start:** set the task's Status to `In progress` and put your name in Owner, then **commit and push that change alone** (`claim T11`) before writing any code.
3. **Never start a task that is `In progress` by someone else.** If an `In progress` task has had no commit for about 60 minutes, ask its owner before taking it over.
4. You may take any `Not started` task whose Depends are all `Done`. Prefer the top of **Next up**.
5. **If blocked or the plan changes while working:** set Status to `Blocked` (or update the Note), and say why and who or what can unblock it. Do not wait silently.
6. **After finishing:** set Status to `Done`, add a short Note, add a **Change log** entry (newest first), refresh **Next up**, and push.
7. **Never mark `Done` unless it actually works** (ran it, tried it, Jac code validated with the Jac MCP). A half-working task stays `In progress`.
8. **Edit only your own rows**, the Next up list and the top of the Change log. Pull before editing. On a merge conflict, keep both sides' changes.
9. **Jac-first:** at least 80% of the code must be Jac. Never swap Jac for Python or JS to get unblocked; mark `Blocked` instead (see `skill.md`).
10. **New feature or change of direction:** update `progress.md` **and every other affected file** (`plan.md`, `README.md`, `skill.md`) in the same commit, so all four stay consistent. List every touched file in the Change log. If unsure which files are affected, check all of them.
11. Never commit API keys. Use `.env` (listed in `.gitignore`).

**Statuses:** `Not started` · `In progress` · `Done` · `Blocked`
**Owner:** a first name from the Team table (`All` only for tasks every member does themselves).

## 2. Team
| Person | Agent | Area (proposed, change if needed) |
|---|---|---|
| Dimuth | Claude Code | Jac backend and agents |
| Sethika | Codex | Frontend, UI/UX, hospital dashboard |
| Akeesha | Codex | Data, Geoapify, demo, README |

## 3. Workflow (phases in order)
| Phase | Time | Tasks | Gate: what must work before moving on |
|---|---|---|---|
| 2026-10-17 | Dimuth | T10 done: Triage Agent (by llm with retry, keyword red-flag rules, rule fallback, safety override, timeline events), 5 MockLLM tests | triage.jac, triage.test.jac, progress.md |
| 2026-10-17 | Dimuth | T09 done: AgentEvent log helpers (start/finish/log_event, compact_case, case_events endpoint), byllm model config in jac.toml, MockLLM convention test | agent_log.jac, agent_log.test.jac, main.jac, jac.toml, .env.example, progress.md |
| 2026-10-17 | Dimuth | T06 done: hospital login (token sessions), list/get hospitals, set and change free beds, `add_hospital` seeding helper, unit test, endpoints registered in main.jac | hospitals.jac, hospitals.test.jac, models.jac, main.jac, progress.md |
| 2026-10-17 | Dimuth | T05 done: graph model and shared types (7 nodes, 4 edges, 7 enums, Location obj), validated with `jac check` and a runtime smoke test | models.jac, progress.md |
| 2026-10-17 | Dimuth | T01 done: Jac fullstack scaffold (main.jac, endpoints.jac, frontend.cl.jac, components/), jac.toml with microservice auto-detect disabled, .gitignore, .env.example, data/ | jac.toml, main.jac, endpoints.jac, frontend.cl.jac, frontend.impl.jac, components/, .gitignore, .env.example, AGENTS.md, progress.md |
| P0 Setup | 9:00 to 9:45 | T00-T03 | Jac app runs, Jac MCP works for everyone, keys in place |
| P1 Data and hospital side | 9:45 to 11:30 | T04-T08 | Hospital logs in and changes beds on the dashboard |
| P2 Patient flow and Triage | 11:30 to 1:30 | T09-T13 | Patient describes a case, sees the agent timeline, gets a triage result |
| P3 Matching and map | 1:30 to 2:30 | T14-T16 | Best hospital, alternatives and route shown on a map |
| P4 Critical flow | 2:30 to 3:30 | T17-T21 | Countdown, dispatch, hospital alert, decline then re-plan, all live |
| P5 Clinic | 3:30 to 4:15 | T22-T23 | Clinic patient gets an in-app notice and mock email |
| P6 PDF and polish | 4:15 to 4:45 | T24-T28 | **Feature freeze 4:45.** Fallbacks, polish, Jac share 80%+ |
| P7 Submit | 4:45 to 5:30 | T29-T32 | Deployed, video recorded, submitted |

## 4. Task tracker
| ID | Task | Ref | Owner | Status | Depends | Note |
|---|---|---|---|---|---|---|
| T00 | Register and check in (every member, 8:00 AM) | rules | All | Done | | Tick names here: Sethika ✅, Akeesha ✅, Dimuth ✅ |
| T01 | Repo skeleton: `pip install jaseci`, Jac app runs, folders, `.gitignore`, `.env.example` | plan 6 | Dimuth | Done | | Fullstack scaffold runs (`jac start --dev main.jac`, page + walkers verified). `[plugins.scale.microservices] enabled = false` in jac.toml stops jac-scale auto-microservice mode; server module is plain `endpoints.jac`. |
| T02 | Jac MCP + Jac skills on each machine (`codex mcp add jac -- jac mcp`, `claude mcp add jac -- jac mcp`, `jac guide --export .claude/skills`) | skill | All | Done | T01 | Tick names here: Akeesha ✅ (Jac 0.16.7 and Jac MCP verified); Sethika ✅ (Jac 0.16.7; Jac MCP registered and verified); Dimuth ✅ (skills exported; MCP registration unavailable because `claude` CLI is not on PATH). Team confirmed complete. |
| T03 | API keys: free LLM key (Gemini or Groq) and Geoapify key, local `.env` only | plan 6 | Akeesha | Done | | Gemini and Geoapify credentials are stored only in ignored `.env`; both were validated against their provider APIs without exposing values. |
| T04 | Fake Sri Lanka hospital dataset (public and private, units, beds, coordinates) | plan F1 | Akeesha | Done | T01 | 10 fictional hospitals across Sri Lanka (6 public, 4 private), 46 unit/bed records, idempotent lazy graph seeding; Jac MCP/CLI validation, tests and live endpoint verified. |
| T05 | Graph model and shared types: Hospital, Unit, BedStatus, CaseState, AgentEvent, ClinicPatient, Request | A9 | Dimuth | Done | T01 | Model in `models.jac` (checked, smoke-tested); summary in Shared notes |
| T06 | Hospital login + bed-update backend | plan F2 | Dimuth | Done | T05 | API in `hospitals.jac`, shape in Shared notes; unit test passes (`jac test hospitals.jac`) |
| T07 | Design system and app shell: tokens, fonts, layout, SafetyBanner, base components, responsive | B1-B3 | Sethika | Done | T01 | Responsive Jac shell, persistent safety banner, Patient/Hospital/Clinic navigation, and reusable UI primitives verified at 360/768/1280 px; Jac MCP validation/lint and live app checks pass. |
| T08 | Hospital dashboard UI: login page, bed cards, BedStepper | B5 | Sethika | In progress | T06, T07 | Claimed by Sethika. |
| T09 | Agent conventions: `llm` setup, typed outputs, AgentEvent logging helper | A0, A8 | Dimuth | Done | T05 | Helpers in `agent_log.jac`; `by llm()` checked with MockLLM; real model needs T03 keys |
| T10 | Triage Agent: `by llm()`, red-flag override, fallback | A2 | Dimuth | Done | T09 | `triage.jac`; 5 tests pass with MockLLM, not yet tried with a real model (needs T03 key) |
| T11 | Patient form UI: description with example chips, location, optional PDF drop zone | B5 | Sethika | Not started | T07 | |
| T12 | AgentTimeline UI: expandable steps, polls events | B4 | Sethika | Not started | T09 | Build early, it makes every agent visible |
| T13 | Orchestrator Agent: `decide_next` by llm(), guard rules, follow-up question flow | A1 | Dimuth | In progress | T10 | |
| T14 | Geoapify: geocode and autocomplete, routing and ETA, caching | plan F5 | Akeesha | In progress | T03 | Claimed by Akeesha. |
| T15 | Hospital Matcher Agent with tools and deterministic fallback | A4 | Dimuth | Not started | T04, T05, T14 | |
| T16 | Result UI: HospitalCard, AlternativesList with reasons, MapPanel with route | B3 | Sethika | Not started | T14, T15 | |
| T17 | Dispatch Agent + simulated ambulance, police and hospital requests + accept/decline endpoints | A5 | Dimuth | Not started | T15 | |
| T18 | CountdownBanner (10 s, Cancel) + live dispatch status panel | B5 | Sethika | Not started | T17 | |
| T19 | Hospital incoming alerts: AlertCard with Accept and Decline in the dashboard | B3, B5 | Sethika | Not started | T08, T17 | |
| T20 | Re-plan Agent: decline, full or timeout → re-match and re-dispatch | A6 | Dimuth | Not started | T17, T19 | |
| T21 | Map: moving ambulance marker and police clearance panel | B3 | Akeesha | Not started | T16, T17 | |
| T22 | Clinic Reminder Agent + ClinicPatient profile + mock email inbox | A7 | Dimuth | Not started | T05 | |
| T23 | Clinic UI: form, reminder card, EmailPreview, in-app notices | B5 | Akeesha | Not started | T07, T22 | |
| T24 | Document Agent: pypdf extractor + `summarise_report` | A3 | Dimuth | Not started | T10 | |
| T25 | Reliability: timeouts, retries, fallbacks, "Using backup logic" banner, canned demo results | A10 | Dimuth | Not started | T13, T15 | |
| T26 | UI polish: loading, empty and error states, responsive check (360/768/1280), accessibility, microcopy | B6 | Sethika | Not started | T16, T18 | |
| T27 | Demo tools: Load demo scenario, Reset demo data, Skip time | B7 | Akeesha | Not started | T22 | |
| T28 | Jac share check at midday and 4:00 PM; fix if under 80% | plan 10 | Akeesha | Not started | T01 | Ask Jaseci staff how it is measured |
| T29 | Deploy to Jac Hammer + local fallback | plan 6 | Akeesha | Not started | T26 | |
| T30 | Record demo video (both scenarios) | plan 9 | Sethika | Not started | T29 | Due 5:30 PM |
| T31 | Final README (setup, usage, structure, links, screenshots) + written description of how Jac/Jaseci was used | README | Akeesha | Not started | T29 | |
| T32 | Submit via the shared link (GitHub link, video, description) and star the Jac repo | plan 9 | Dimuth | Not started | T30, T31 | Before 5:30 PM, late entries can't win |

## 5. Next up
Keep this to 3 to 6 items and refresh it whenever a task is Done.
1. **T08** Sethika: hospital dashboard UI
2. **T13** Dimuth: Orchestrator Agent (`decide_next`, guard rules, follow-up flow)
3. **T11** Sethika: patient form UI
4. **T14** Akeesha: Geoapify geocoding, routing, ETA and caching
5. **T12** Sethika: live agent timeline UI
6. **T28** Akeesha: Jac share check

## 6. Shared notes (blockers, interface changes, decisions)
Add a dated line when an API shape, data model or decision changes. Newest first.
- 2026-10-17: **Triage Agent (T10)** in `triage.jac`. `triage_case(cs: CaseState) -> TriageResult` rates a case: model first (retried once), keyword rules as backup, and a safety override so the model can never go below the rules. It writes severity, unit_needed, red_flags, confidence, followup_question and status (TRIAGED, or NEEDS_INFO when it needs a follow-up) onto the CaseState, sets `used_fallback`, and logs one timeline step ("Using backup logic" in the detail when the fallback ran). Reusable pieces: `red_flag_check`, `rule_triage`, `apply_override`. T13 (Orchestrator) calls `triage_case`.
- 2026-10-17: **Frontend shell (T07)** exports `AppHeader`, `SafetyBanner`, and `UiKit` primitives (`StatusBadge`, `SurfaceCard`, `AppButton`, `EmptyState`) from `components/*.cl.jac`. Global tokens and responsive layout live in `assets/theme.css`; extend these rather than adding one-off inline styles. The shell's Patient/Hospital/Clinic buttons currently select clearly labelled placeholders for T11, T08, and T23.
- 2026-10-17: **Agent conventions (T09)** in `agent_log.jac`. Pattern: `ev = start_event(cs, agent, step, title)` then run the typed `by llm(temperature=0.2)` function with `compact_case(cs)`, then `finish_event(ev, EventStatus.DONE|FAILED|WAITING, title, detail)`; or `log_event(...)` in one call. **Timeline API (T12): `case_events(case_id) -> list[EventView{id, case_id, agent, step, status, title, detail, timestamp}]`, oldest first, status is "RUNNING"|"DONE"|"FAILED"|"WAITING".** Model is set in `jac.toml` `[plugins.byllm.model] default_model` (env `LLM_MODEL`, default `gemini/gemini-2.0-flash`); key goes in `.env` (T03). `case` is a reserved word in Jac, do not use it as a variable name. Tests use `MockLLM` so no key is needed.
- 2026-10-17: **Hospital API (T06)** in `hospitals.jac`, all `def:pub`, call as `POST /function/<name>` (or `sv import` in a `.cl.jac`). `list_hospitals() -> list[HospitalView]`, `get_hospital(hospital_id)`, `hospital_login(username, password) -> LoginResult{ok, token, hospital_id, message}`, `hospital_logout(token)`, `my_hospital(token)`, `set_free_beds(token, unit_type, free)`, `change_free_beds(token, unit_type, delta)` (BedStepper +/-). `HospitalView{id, name, sector, city, lat, lon, units: list[UnitView{unit_type, total, free}]}`; unit_type/sector are enum names like "ICU", "PUBLIC". Write endpoints return the updated HospitalView, or None when the token is missing or expired (treat as logged out). Sessions are in memory, so a server restart signs everyone out. **Akeesha (T04):** seed with `add_hospital(name, Sector.X, city, lat, lon, username, password, {"ICU": 10, "CARDIAC": 6})` from `hospitals.jac`. Added `password_hash` to Hospital in `models.jac`.
- 2026-10-17: **Data model (T05) is in `models.jac`**, import with `import from models { Hospital, ... }`. Graph: `root --> Hospital --HasUnit--> Unit --HasBeds--> BedStatus(total, free)`; `root --> CaseState --CaseEvent--> AgentEvent`, `--CaseRequest--> Request`; `root --> ClinicPatient`. Enums: Severity (CRITICAL/URGENT/STABLE), Sector (PUBLIC/PRIVATE), UnitType (CARDIAC/TRAUMA/ICU/NEURO/GENERAL), CaseStatus, EventStatus (RUNNING/DONE/FAILED/WAITING), RequestKind (AMBULANCE/POLICE/HOSPITAL_ALERT), RequestStatus. `Location(lat, lon, address)` is a plain obj. Seed data (T04) must create Hospital -> Unit -> BedStatus with these fields. Ask Dimuth before changing a field.
- 2026-10-17: T01 is Done, `git pull` to get the skeleton. Run the app with `jac start --dev main.jac` (open http://localhost:8000). `main.jac`, `endpoints.jac`, `frontend.cl.jac`, `frontend.impl.jac` and `components/MessageCard.cl.jac` are generated guestbook placeholders, replace them. Keep `[plugins.scale.microservices] enabled = false` in `jac.toml` or jac-scale auto-switches to microservice mode and the page 404s. Unblocked now: T02, T04, T05, T07 (all depend only on T01).
- 2026-10-17: Dispatch uses a 10-second cancellable countdown. Orchestrator, re-plan, hospital Accept/Decline and clinic-patient profile are in scope (see `skill.md`).

## 7. Change log (newest first)
Add one entry per completed piece of work: date and time, who, what changed, files touched.

| Date | Who | What changed | Files |
|---|---|---|---|
| 2026-10-17 10:30 | Sethika | Completed T07: replaced the guestbook with a responsive, stateful CareRoute shell; added persistent medical safety messaging, Patient/Hospital/Clinic navigation, reusable UI primitives, accessible design tokens, documentation, and verified 360/768/1280 layouts plus navigation interactions | frontend.cl.jac, frontend.impl.jac, components/AppHeader.cl.jac, components/SafetyBanner.cl.jac, components/UiKit.cl.jac, assets/theme.css, PLAN.md, README.md, CHANGELOG.md, progress.md |
| 2026-10-17 | Akeesha | Completed T04: added a typed Jac dataset of 10 fictional Sri Lankan hospitals with 46 unit/bed records, integrated idempotent lazy graph seeding with the hospital API, and verified data integrity plus the live list endpoint | data/hospital_seed.jac, data/hospital_seed.test.jac, hospitals.jac, hospitals.test.jac, progress.md |
| 2026-10-17 | Akeesha | Completed T03: moved uploaded credentials out of tracked `.env.example` into ignored `.env`, restored the blank template, and validated Gemini and Geoapify API access without exposing keys | progress.md (credentials remain local in `.env`) |
| 2026-10-17 10:05 | Sethika | Marked shared T02 Done after team confirmation, refreshed Next up, and cleared T07's resolved T01 blocker | progress.md |
| 2026-10-17 09:52 | Sethika | Completed Sethika's T02 setup: verified Jac 0.16.7 and jac-mcp 0.1.24, registered the Jac MCP in Codex, and confirmed it is enabled | progress.md |
| 2026-10-17 09:39 | Sethika | Completed Sethika's T00 registration check-in; shared task remains in progress for the other team members | progress.md |
| 2026-10-17 | Dimuth | Created this tracker with rules, team, workflow, 33 tasks, next up. Updated plan and README to match skill.md: 10-second countdown, Orchestrator and Re-plan agents, hospital Accept/Decline, clinic profile, `pip install jaseci`, Jac MCP, team agents | progress.md, plan.md, README.md |
| 2026-10-17 | Dimuth | Added Jac-first rules (80%+) and Jac MCP setup for Codex and Claude Code | skill.md |
| 2026-10-17 | Dimuth | Created skill.md: agent skills (by llm(), Orchestrator, re-plan, event log) and UI/UX guide | skill.md |
| 2026-10-17 | Dimuth | Created README.md with problem, features, stack and setup placeholders | README.md |
| 2026-10-17 | Dimuth | Created plan.md: goal, scope, agents, features, milestones, risks | plan.md |
