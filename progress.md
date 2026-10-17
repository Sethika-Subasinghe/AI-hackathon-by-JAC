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
| T00 | Register and check in (every member, 8:00 AM) | rules | All | In progress | | Tick names here: Sethika ✅ |
| T01 | Repo skeleton: `pip install jaseci`, Jac app runs, folders, `.gitignore`, `.env.example` | plan 6 | Dimuth | In progress | | |
| T02 | Jac MCP + Jac skills on each machine (`codex mcp add jac -- jac mcp`, `claude mcp add jac -- jac mcp`, `jac guide --export .claude/skills`) | skill | All | Not started | T01 | Tick names here: |
| T03 | API keys: free LLM key (Gemini or Groq) and Geoapify key, local `.env` only | plan 6 | Akeesha | In progress | | Share keys privately, never in git |
| T04 | Fake Sri Lanka hospital dataset (public and private, units, beds, coordinates) | plan F1 | Akeesha | Not started | T01 | |
| T05 | Graph model and shared types: Hospital, Unit, BedStatus, CaseState, AgentEvent, ClinicPatient, Request | A9 | Dimuth | Not started | T01 | Post data model in Shared notes |
| T06 | Hospital login + bed-update backend | plan F2 | Dimuth | Not started | T05 | Post API shape in Shared notes |
| T07 | Design system and app shell: tokens, fonts, layout, SafetyBanner, base components, responsive | B1-B3 | Sethika | Not started | T01 | |
| T08 | Hospital dashboard UI: login page, bed cards, BedStepper | B5 | Sethika | Not started | T06, T07 | |
| T09 | Agent conventions: `llm` setup, typed outputs, AgentEvent logging helper | A0, A8 | Dimuth | Not started | T05 | |
| T10 | Triage Agent: `by llm()`, red-flag override, fallback | A2 | Dimuth | Not started | T09 | |
| T11 | Patient form UI: description with example chips, location, optional PDF drop zone | B5 | Sethika | Not started | T07 | |
| T12 | AgentTimeline UI: expandable steps, polls events | B4 | Sethika | Not started | T09 | Build early, it makes every agent visible |
| T13 | Orchestrator Agent: `decide_next` by llm(), guard rules, follow-up question flow | A1 | Dimuth | Not started | T10 | |
| T14 | Geoapify: geocode and autocomplete, routing and ETA, caching | plan F5 | Akeesha | Not started | T03 | |
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
1. **T00** All: register and check in
2. **T01** Dimuth: repo skeleton and Jac app running
3. **T03** Akeesha: LLM and Geoapify keys
4. **T02** All: Jac MCP on every machine (after T01)
5. **T07** Sethika: design system and app shell (after T01)
6. **T04** Akeesha: fake hospital dataset (after T01)

## 6. Shared notes (blockers, interface changes, decisions)
Add a dated line when an API shape, data model or decision changes. Newest first.
- 2026-10-17: Dispatch uses a 10-second cancellable countdown. Orchestrator, re-plan, hospital Accept/Decline and clinic-patient profile are in scope (see `skill.md`).

## 7. Change log (newest first)
Add one entry per completed piece of work: date and time, who, what changed, files touched.

| Date | Who | What changed | Files |
|---|---|---|---|
| 2026-10-17 09:39 | Sethika | Completed Sethika's T00 registration check-in; shared task remains in progress for the other team members | progress.md |
| 2026-10-17 | Dimuth | Created this tracker with rules, team, workflow, 33 tasks, next up. Updated plan and README to match skill.md: 10-second countdown, Orchestrator and Re-plan agents, hospital Accept/Decline, clinic profile, `pip install jaseci`, Jac MCP, team agents | progress.md, plan.md, README.md |
| 2026-10-17 | Dimuth | Added Jac-first rules (80%+) and Jac MCP setup for Codex and Claude Code | skill.md |
| 2026-10-17 | Dimuth | Created skill.md: agent skills (by llm(), Orchestrator, re-plan, event log) and UI/UX guide | skill.md |
| 2026-10-17 | Dimuth | Created README.md with problem, features, stack and setup placeholders | README.md |
| 2026-10-17 | Dimuth | Created plan.md: goal, scope, agents, features, milestones, risks | plan.md |
