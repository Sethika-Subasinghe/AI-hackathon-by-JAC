# Plan: Emergency Hospital Finder (Jac AI Hackathon 2026)

Hacking: 9:00 AM to 5:30 PM, Sat 17 Oct 2026. Submission: GitHub link (80%+ Jac), demo video, written description (how Jac/Jaseci was used). Star github.com/jaseci-labs/jac. Host on Jac Hammer if time allows.

## 1. Goal
A web app where a patient or family describes a medical condition (optional PDF report) and an AI agent system finds the best hospital with free beds nearby, public or private. Critical cases also trigger an ambulance request, police route clearance and a pre-arrival alert to the hospital. Clinic patients get reminders for their clinic date.

Problem: in an emergency, families don't know which hospital has capacity or the right unit, and hospitals get no warning before a patient arrives.

## 2. Users
- **Patient / family** (main user): describe condition, share location, get a hospital recommendation.
- **Hospital staff**: log in, update bed availability, see incoming-patient alerts and accept or decline them.
- **Ambulance and police**: simulated receivers of dispatch and route-clearance requests (demo only).

## 3. Scope
**In scope (demo):** fake Sri Lanka hospital data (public and private), triage, hospital matching with ETA, critical-case dispatch flow (simulated), hospital dashboard with login, clinic reminders (in-app + mock email), optional PDF upload.

**Out of scope:** real ambulance/police integration, real diagnosis, real patient data, production auth hardening.

**Safety notice (always shown):** "This is not a medical diagnosis. In a real emergency call 1990." The triage agent outputs urgency and the care needed, never a diagnosis. Critical dispatch starts a 10-second countdown that the patient can cancel.

## 4. Agents (priority: agentic behaviour)
An Orchestrator agent decides which agent runs next. Each agent has a clear job, uses tools (built with Jac `by llm()`), and passes structured output on. Details are in `skill.md`.

1. **Triage Agent**: reads the free text and PDF summary, returns severity (critical / urgent / stable), required unit (trauma, cardiac, ICU, neuro, general), red flags and confidence. Asks follow-up questions if the input is too vague.
2. **Hospital Matcher Agent**: tools = hospital graph query, Geoapify routing/ETA. Filters by unit and free beds, scores by ETA, capacity and sector, returns the best hospital plus ranked alternatives with a reason for each.
3. **Emergency Dispatch Agent (critical only)**: after a 10-second countdown the patient can cancel, creates an ambulance request, a police route-clearance request (with the route from Geoapify) and a "get ready" alert to the chosen hospital. Logs each step so the demo shows the chain.
4. **Clinic Reminder Agent**: takes clinic name, date and condition, schedules reminders, suggests a good arrival time based on hospital load, sends in-app notice and mock email.
5. **Document Agent (small)**: extracts text from the PDF and summarises the key medical facts for the Triage Agent.
6. **Orchestrator Agent**: decides the next step for each case (read the PDF only if one exists, ask a follow-up, triage, match, dispatch only if critical, re-plan). Deterministic guard rules can veto its choices.
7. **Re-plan Agent**: if the chosen hospital declines, runs out of beds or does not respond, excludes it, re-matches and re-dispatches to the next best hospital (max 3 times).

## 5. Features, added step by step
1. Fake hospital dataset + graph model (nodes: Hospital, Unit, BedStatus)
2. Hospital login + bed-availability dashboard
3. Patient form (text, location, optional PDF)
4. Triage Agent, agent event log with live agent timeline, Orchestrator Agent
5. Hospital Matcher + Geoapify (geocoding, routing, map)
6. Alternatives list with reasons
7. Critical flow: Dispatch Agent with 10-second cancel countdown, hospital incoming-patient alert with Accept/Decline, simulated ambulance/police panel, automatic re-planning
8. Clinic Reminder Agent + saved clinic-patient profile + mock email, then real email as a stretch
9. PDF Document Agent
10. Polish: loading states, error handling, demo data reset, disclaimer

## 6. Tech stack
- **Language:** Jac, at least 80% of code, covering backend and frontend. Use nodes/edges/walkers for the hospital graph and `by llm` style agent functions for the AI parts. Plain JS/CSS only where Jac can't cover it (keep under 20%). Verify exact syntax against jaclang.org/docs/latest.
- **LLM:** a free-tier API key (Gemini or Groq). Cache results and keep prompts short to stay under rate limits.
- **Location:** Geoapify (geocoding, routing, places, map tiles).
- **Email:** mock first (render the email in the app), real SMTP/Resend only as a stretch.
- **PDF text:** a small Python extractor (pypdf) called from Jac.
- **Hosting:** Jac Hammer sandbox for judges, local fallback for the video.
- **Jac tooling:** `pip install jaseci`. Coding agents use the Jac MCP server (`codex mcp add jac -- jac mcp` or `claude mcp add jac -- jac mcp`) to validate Jac code. See `skill.md`.
- **UI:** medical theme, responsive on phone, tablet and PC, English only (see `skill.md` Part B).

## 7. Team and workflow
Dimuth (Claude Code): Jac backend and agents. Sethika (Codex): frontend and hospital dashboard. Akeesha (Codex): data, Geoapify, demo, README. This split is proposed and can be changed in `progress.md`.

Coordination runs through `progress.md`, which holds the agent rules, task tracker, next-up list and change log:
- Every agent reads it first, claims a task (status In progress + owner) and pushes the claim before starting, then marks Done and adds a change log entry when finished.
- A new feature or change of direction updates `progress.md`, `plan.md`, `README.md` and `skill.md` together.

## 8. Milestones (9:00 AM to 5:30 PM)
| Time | Milestone |
|---|---|
| 9:00 to 9:45 | Repo, Jac project running, keys (LLM, Geoapify), `progress.md` agreed |
| 9:45 to 11:30 | Hospital data + graph, login, bed dashboard (features 1-2) |
| 11:30 to 1:30 | Patient form, Triage Agent, Matcher end to end (3-4, 6) |
| 1:30 to 2:30 | Geoapify routing, ETA, map (5) |
| 2:30 to 3:30 | Critical flow: dispatch, hospital alert, police panel (7) |
| 3:30 to 4:15 | Clinic reminders + mock email (8) |
| 4:15 to 4:45 | PDF agent and polish (9-10). Feature freeze at 4:45 |
| 4:45 to 5:30 | Deploy, record demo video, README and description, submit with buffer |

## 9. Definition of done
- Scenario 1 (critical, e.g. chest pain): triage → best hospital with ETA → alternatives → 10-second cancellable countdown → ambulance and police requests → hospital sees the incoming alert and can accept or decline (a decline triggers re-planning to the next hospital), all working live and visible in the agent timeline.
- Scenario 2 (clinic patient): enters clinic date, gets reminder in-app and as mock email.
- Hospital can log in and change beds, and the next recommendation changes accordingly.
- Submitted by 5:30 PM: GitHub link (80%+ Jac), demo video, written description of Jac/Jaseci usage, repo starred.

## 10. Risks
| Risk | Mitigation |
|---|---|
| Team's Jac experience is thin, build slows | Lean on Jaseci staff on-site, keep docs open, build vertical slices |
| Free LLM rate limits or slow replies | Cache, short prompts, fallback canned responses for the demo scenarios |
| Geoapify free-tier limits | Cache geocoding and routes, limit calls per request |
| Scope too big for ~7 hours | Strict order in section 5, feature freeze at 4:45, simulate integrations |
| Two AI coding agents conflict | `progress.md` ownership, small commits, separate folders per member |
| Under 80% Jac | Check the language split on GitHub at midday and at 4:00 |
| Medical safety / misuse | Disclaimer, no diagnosis, cancellable countdown before dispatch, fake data only |
| Demo fails live | Pre-recorded video, seeded demo data, one-click reset |
